private let serviceCacheKey = "vapor:serviceCache"

extension Droplet {
    /// Makes all available services for the given type.
    ///
    /// If a protocol is supplied, all services conforming
    /// to the protocol will be returned.
    ///
    /// Service type names that appear in the `droplet.json` file
    /// will be return in the results.
    ///
    /// The following example will initialize three service
    /// types matching the names "error", "date", and "file".
    ///
    ///     `Config/droplet.json`
    ///     { "middleware": ["error", "date", "file"] }
    ///
    /// The ordering from the config array is respected.
    ///
    /// Manually setting config also works.
    ///
    ///     try config.set("droplet.middleware", [
    ///         "error", "date", "file"
    ///     ])
    ///     let drop = try Droplet(config, ...)
    ///
    /// Any service instances matching this type will be
    /// appended to the end of the results.
    ///
    public func make<Type>(_ type: [Type.Type] = [Type.self]) throws -> [Type] {
        // create a readable key name for this service type
        // this will be used in the config
        // for example, `ConsoleProtocol` -> `console`
        var typeName = makeTypeName(Type.self)
        if typeName != "middleware" {
            typeName += "s"
        }

        // create a key name for caching the result
        // the make array always caches
        let keyName = "array-\(typeName)"

        // check to see if we already have a cached result
        if let existing = serviceCache[keyName] as? [Type] {
            return existing
        }

        // find all available service types
        let availableServices = services.factories(supporting: Type.self)

        // get the array of services specified in config
        // for this type.
        // if no services are specified, return only instances.
        guard let chosen = config["droplet", typeName]?.array?.flatMap({ $0.string }) else {
            return []
        }

        // loop over chosen service names from config
        // and convert to ServiceTypes from the Services struct.
        let chosenServices: [ServiceFactory] = try chosen.map { chosenName in
            // resolve services matching the supplied name
            let resolvedServices: [ServiceFactory] = availableServices.flatMap { availableService in
                guard availableService.serviceName == chosenName else {
                    return nil
                }

                return availableService
            }

            if resolvedServices.count > 1 {
                // multiple services have the same name
                // this is bad.
                throw ServiceError.duplicateServiceName(
                    name: chosenName,
                    type: Type.self
                )
            } else if resolvedServices.count == 0 {
                // no services were found that have this name.
                throw ServiceError.unknownService(
                    name: chosenName,
                    available: availableServices.map({ $0.serviceName }),
                    type: Type.self
                )
            } else {
                // the service they wanted was found!
                return resolvedServices[0]
            }
        }

        // lazy loading
        // initialize all of the requested services type.
        // then append onto that the already intialized service instances.
        let array = try chosenServices.flatMap { chosenService in
            return try _makeServiceFactoryConsultingCache(chosenService, ofType: Type.self)
        }

        // cache the result
        serviceCache[keyName] = array

        return array
    }

    /// Returns or creates a service for the given type.
    ///
    /// If a protocol is supplied, a service conforming
    /// to the protocol will be returned.
    ///
    /// If multiple available services conform to the 
    /// supplied protocol, you will need to disambiguate in
    /// the Droplet's configuration.
    ///
    /// This can be done using config files:
    ///
    ///     `Config/droplet.json`
    ///     { "client": "engine" }
    ///
    /// Disambiguation can also be done manually:
    ///
    ///     try config.set("droplet.client", "engine")
    ///     let drop = try Droplet(config, ...)
    ///
    public func make<Type>(_ type: Type.Type = Type.self) throws -> Type {
        // generate a readable name from the type for config
        // ex: `ConsoleProtocol` -> 'console'
        let typeName = makeTypeName(Type.self)

        // find all available service types that match the requested type.
        let available = services.factories(supporting: Type.self)

        let chosen: ServiceFactory

        if available.count > 1 {
            // multiple services are available,
            // we will need to disambiguate
            guard let disambiguation = config["droplet", typeName]?.string else {
                // no dismabiguating configuration was given. 
                // we are unable to choose which service to use.
                throw ServiceError.disambiguationRequired(
                    key: typeName,
                    available: available.flatMap({ $0.serviceName }),
                    type: Type.self
                )
            }

            // turn the disambiguated type name into a ServiceType
            // from the available service types.
            let disambiguated: [ServiceFactory] = available.flatMap { service in
                guard disambiguation == service.serviceName else {
                    return nil
                }
                return service
            }

            if disambiguated.count > 1 {
                // multiple service types were found with the same name.
                // this is bad.
                throw ServiceError.duplicateServiceName(
                    name: disambiguation,
                    type: Type.self
                )
            } else if disambiguated.count == 0 {
                // no services were found that matched the supplied name.
                // we are uanble to choose which service to use.
                throw ServiceError.unknownService(
                    name: disambiguation,
                    available: available.flatMap({ $0.serviceName }),
                    type: Type.self
                )
            } else {
                // the desired service was found, use it!
                chosen = disambiguated.first!
            }
        } else if available.count == 0 {
            // no services are available matching
            // the type requested.
            throw ServiceError.noneAvailable(type: Type.self)
        } else {
            // only one service matches, no need to disambiguate.
            // let's use it!
            chosen = available.first!
        }

        // lazy loading
        // create an instance of this service type.
        let item = try _makeServiceFactoryConsultingCache(chosen, ofType: Type.self)

        return item!
    }

    fileprivate func _makeServiceFactoryConsultingCache<T>(
        _ serviceFactory: ServiceFactory, ofType: T.Type
    ) throws -> T? {
        let key = "\(serviceFactory.serviceType)-\(serviceFactory.serviceName)"
        if serviceFactory.serviceIsSingleton {
            if let cached = serviceCache[key] as? T {
                return cached
            }
        }

        guard let new = try serviceFactory.makeService(for: self) as? T? else {
            throw ServiceError.incorrectType(
                name: serviceFactory.serviceName,
                type: serviceFactory.serviceType,
                desired: T.self
            )
        }

        if serviceFactory.serviceIsSingleton {
            serviceCache[key] = new
        }

        return new
    }

    fileprivate var serviceCache: [String: Any] {
        get {
            return storage[serviceCacheKey] as? [String: Any] ?? [:]
        }
        set {
            storage[serviceCacheKey] = newValue
        }
    }
}

// MARK: Service Utilities

extension Services {
    internal func factories<P>(supporting protocol: P.Type) -> [ServiceFactory] {
        return factories.filter { factory in
            return _type(factory.serviceType, supports: P.self)
        }
    }
}

private func _type<P>(_ any: Any.Type, supports protocol: P.Type) -> Bool {
    return any is P
}

// MARK: Utilities

private var typeNameCache: [String: String] = [:]

private func makeTypeName<T>(_ any: T.Type) -> String {
    let rawTypeString = "\(T.self)"
    if let cached = typeNameCache[rawTypeString] {
        return cached
    }

    let formattedTypename = rawTypeString
        .replacingOccurrences(of: "Protocol", with: "")
        .replacingOccurrences(of: "Factory", with: "")
        .replacingOccurrences(of: "Renderer", with: "")
        .splitUppercaseCharacters()
        .joined(separator: "-")
        .lowercased()

    typeNameCache[rawTypeString] = formattedTypename
    return formattedTypename
}
