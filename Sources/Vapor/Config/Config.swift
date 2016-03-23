public class Config {
	public static let configDir = Application.workDir + "Config"
	private var repository: [String: Json]

	public init(repository: [String: Json] = [:], application: Application? = nil) {
		self.repository = repository

		if let application = application {
			populate(application)
		}
	}

	public func has(keyPath: String) -> Bool {
		return get(keyPath) != nil
	}

	public func get(keyPath: String) -> Json? {
		var keys = keyPath.keys

		guard keys.count > 0 else {
			return nil
		}

		var value = repository[keys.removeFirst()]

		while value != nil && value != Json.NullValue && keys.count > 0 {
			value = value?[keys.removeFirst()]
		}

		return value
	}

	public func get(keyPath: String, _ fallback: String) -> String {
		return get(keyPath)?.string ?? fallback
	}

	public func get(keyPath: String, _ fallback: Bool) -> Bool {
		return get(keyPath)?.bool ?? fallback
	}

	public func get(keyPath: String, _ fallback: Int) -> Int {
		return get(keyPath)?.int ?? fallback
	}

	public func get(keyPath: String, _ fallback: UInt) -> UInt {
		return get(keyPath)?.uint ?? fallback
	}

	public func get(keyPath: String, _ fallback: Double) -> Double {
		return get(keyPath)?.double ?? fallback
	}

	public func get(keyPath: String, _ fallback: Float) -> Float {
		return get(keyPath)?.float ?? fallback
	}

	public func set(value: Json, forKeyPath keyPath: String) {
		var keys = keyPath.keys
		let group = keys.removeFirst()

		if keys.count == 0 {
			repository[group] = value
		} else {
			repository[group]?.set(value, keys: keyPath.keys)
		}
	}

	/* Convenience call to conditionally populate config if it exists */
	public func populate(application: Application) -> Bool {
		if FileManager.fileAtPath(self.dynamicType.configDir).exists {
			do {
				try populate(self.dynamicType.configDir, application: application)
				return true
			} catch {
				Log.error("Unable to populate config: \(error)")
				return false
			}
		} else {
			return false
		}
	}

	public func populate(path: String, application: Application) throws {
		var path = path.finish("/")
		var files = [String: [String]]()

		// Populate config files by environment
		try populateConfigFiles(&files, in: path)

		for env in application.environment.description.keys {
			path += env + "/"

			if FileManager.fileAtPath(path).exists {
				try populateConfigFiles(&files, in: path)
			}
		}

		// Loop through files and merge config upwards so the
		// environment always overrides the base config
		for (group, files) in files {
			if group == ".env" {
				// .env is handled differently below
				continue
			}

			for file in files {
				let data = try FileManager.readBytesFromFile(file)
				let json = try Json.deserialize(data)

				if repository[group] == nil {
					repository[group] = json
				} else {
					repository[group]?.merge(with: json)
				}
			}
		}

		// Apply .env overrides, which is a single file
		// containing multiple groups
		if let env = files[".env"] {
			for file in env {
				let data = try FileManager.readBytesFromFile(file)
				let json = try Json.deserialize(data)

				guard case let .ObjectValue(object) = json else {
					return
				}

				for (group, json) in object {
					if repository[group] == nil {
						repository[group] = json
					} else {
						repository[group]?.merge(with: json)
					}
				}
			}
		}
	}

	private func populateConfigFiles(files: inout [String: [String]], in path: String) throws {
		let contents = try FileManager.contentsOfDirectory(path)
		let suffix = ".json"

		for file in contents {
			guard let fileName = file.split("/").last, suffixRange = fileName.rangeOfString(suffix) where suffixRange.endIndex == fileName.characters.endIndex else {
				continue
			}

			let name = fileName.substringToIndex(suffixRange.startIndex)

			if files[name] == nil {
				files[name] = []
			}

			files[name]?.append(file)
		}
	}

}

extension Json {

	mutating private func set(value: Json, keys: [String]) {
		var keys = keys

		guard keys.count > 0 else {
			return
		}

		let key = keys.removeFirst()

		guard case let .ObjectValue(object) = self else {
			return
		}

		var updated = object

		if keys.count == 0 {
			updated[key] = value
		} else {
			var child = updated[key] ?? Json.ObjectValue([:])
			child.set(value, keys: keys)
		}

		self = .ObjectValue(updated)
	}

}

extension String {

	private var keys: [String] {
		return split(".")
	}

}
