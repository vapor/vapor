import Foundation

public class Config {
	public static let configDir = Application.workDir + "Config"
	private let fileManager = NSFileManager.defaultManager()
	private var repository: [String: Json]

	public init(repository: [String: Json] = Dictionary(), application: Application? = nil) {
		self.repository = repository

		if let application = application {
			self.populate(application)
		}
	}

	public func has(keyPath: String) -> Bool {
		return self.get(keyPath) != nil
	}

	public func get(keyPath: String) -> Json? {
		var keys = keyPath.keys

		guard keys.count > 0 else {
			return nil
		}

		var value = self.repository[keys.removeFirst()]

		while value != nil && value != Json.NullValue && keys.count > 0 {
			value = value?[keys.removeFirst()]
		}

		return value
	}

	public func get(keyPath: String, _ fallback: String) -> String {
		return self.get(keyPath)?.string ?? fallback
	}

	public func get(keyPath: String, _ fallback: Bool) -> Bool {
		return self.get(keyPath)?.bool ?? fallback
	}

	public func get(keyPath: String, _ fallback: Int) -> Int {
		return self.get(keyPath)?.int ?? fallback
	}

	public func get(keyPath: String, _ fallback: UInt) -> UInt {
		return self.get(keyPath)?.uint ?? fallback
	}

	public func get(keyPath: String, _ fallback: Double) -> Double {
		return self.get(keyPath)?.double ?? fallback
	}

	public func get(keyPath: String, _ fallback: Float) -> Float {
		return self.get(keyPath)?.float ?? fallback
	}

	public func set(value: Json, forKeyPath keyPath: String) {
		var keys = keyPath.keys
		let group = keys.removeFirst()

		if keys.count == 0 {
			self.repository[group] = value
		} else {
			self.repository[group]?.set(value, keys: keyPath.keys)
		}
	}

	/* Convenience call to conditionally populate config if it exists */
	public func populate(application: Application) -> Bool {
		if NSFileManager.defaultManager().fileExistsAtPath(self.dynamicType.configDir) {
			do {
				try self.populate(self.dynamicType.configDir, application: application)
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
		var url = NSURL(fileURLWithPath: path)
		var files = Dictionary<String, [NSURL]>()

		// Populate config files by environment
		try self.populateConfigFiles(&files, in: url)

		for env in application.environment.description.keys {
			#if os(Linux)
				url = url.URLByAppendingPathComponent(env)!
			#else
				url = url.URLByAppendingPathComponent(env)
			#endif

			if self.fileManager.fileExistsAtPath(url.path!) {
				try self.populateConfigFiles(&files, in: url)
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
				let data = try NSData(contentsOfURL: file, options: [])
				let json = try Json.deserialize(data)

				if self.repository[group] == nil {
					self.repository[group] = json
				} else {
					self.repository[group]?.merge(json)
				}
			}
		}

		// Apply .env overrides, which is a single file
		// containing multiple groups
		if let env = files[".env"] {
			for file in env {
				let data = try NSData(contentsOfURL: file, options: [])
				let json = try Json.deserialize(data)

				guard case let .ObjectValue(object) = json else {
					return
				}

				for (group, json) in object {
					if self.repository[group] == nil {
						self.repository[group] = json
					} else {
						self.repository[group]?.merge(json)
					}
				}
			}
		}
	}

	private func populateConfigFiles(inout files: [String: [NSURL]], in url: NSURL) throws {
		let contents = try self.fileManager.contentsOfDirectoryAtURL(url, includingPropertiesForKeys: nil, options: [ ])

		for file in contents {
			guard file.pathExtension == "json" else {
				continue
			}

			guard let name = file.URLByDeletingPathExtension?.lastPathComponent else {
				continue
			}

			if files[name] == nil {
				files[name] = Array()
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
		return self.split(".")
	}

}
