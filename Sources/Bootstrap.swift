public class Bootstrap {

	public func request(request: Request) {
		Session.start(request)
	}

	public func respond(request: Request, response: Response) {
		Session.close(request: request, response: response)
	}

}