/**
 * The `MemorySessionDriver` stores session data
 * in a Swift `Dictionary`. This means all session
 * data will be purged if the server is restarted.
 */
class MemorySessionDriver: SessionDriver {
	var sessions = [String: Session]()
}