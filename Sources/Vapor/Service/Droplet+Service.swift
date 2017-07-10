private let serviceCacheKey = "vapor:serviceCache"

extension Droplet {
    public func make<Type>(_ type: [Type.Type] = [Type.self]) throws -> [Type] {
        var typeName = makeTypeName(Type.self)
        if typeName != "middleware" {
            typeName += "s"
        }
        let keyName = "array-\(typeName)"

        if let existing = serviceCache[keyName] as? [Type] {
            return existing
        }

        let instances = services.instances(supporting: Type.self).map { service in
            return service.instance as! Type
        }

        let availableServices = services.types(supporting: Type.self)

        guard let chosen = config["droplet", typeName]?.array?.flatMap({ $0.string }) else {
            return instances
        }

        let chosenServices: [ServiceType] = try chosen.map { chosenName in
            let resolvedServices: [ServiceType] = availableServices.flatMap { availableService in
                guard availableService.type.name == chosenName else {
                    return nil
                }

                return availableService
            }

            if resolvedServices.count > 1 {
                throw "Multiple services named \(chosenName) were found for \(Type.self). This is bad"
            } else if resolvedServices.count == 0 {
                print("Available services: ")
                print(availableServices.map({ $0.type.name }))
                throw "No service named \(chosenName) was found for \(Type.self)"
            } else {
                return resolvedServices[0]
            }
        }


        let array = try chosenServices.flatMap { chosenService in
            return try chosenService.type.make(for: self) as! Type?
        } + instances

        serviceCache[keyName] = array
        return array
    }

    public func make<Type>(_ type: Type.Type = Type.self) throws -> Type {
        let typeName = makeTypeName(Type.self)
        let keyName = "single-\(typeName)"

        if let cached = serviceCache[keyName] as? Type {
            return cached
        }

        let instances = services.instances(supporting: Type.self).map { service in
            return service.instance as! Type
        }

        if instances.count > 1 {
            throw "Multiple instances available for \(Type.self). Unable to disambiguate"
        } else if instances.count == 1 {
            return instances[0]
        }

        let available = services.types(supporting: Type.self)
        print(available)

        let chosen: ServiceType
        if available.count > 1 {
            let typeName = makeTypeName(Type.self)
            let serviceNames = available.flatMap { $0.type.name }

            guard let disambiguation = config["droplet", typeName]?.string else {
                print("Available services: ")
                print(serviceNames)
                throw "Multiple services available for \(Type.self). Please disambiguate using config.droplet.\(typeName)"
            }

            let disambiguated: [ServiceType] = available.flatMap { service in
                guard disambiguation == service.type.name else {
                    return nil
                }
                return service
            }

            if disambiguated.count > 1 {
                throw "Multiple services matched \(disambiguation). This is bad"
            } else if disambiguated.count == 0 {
                print("Available services: ")
                print(serviceNames)
                throw "No services matched \(disambiguation)."
            } else {
                chosen = disambiguated.first!
            }
        } else if available.count == 0 {
            throw "No services available for \(Type.self)."
        } else {
            chosen = available.first!
        }


        let item = try chosen.type.make(for: self) as! Type
        if chosen.isSingleton {
            serviceCache[keyName] = item
        }

        return item
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

extension String: Error { }
