/**
	Set a subclass of Bootstrap as the `bootstrap` property on your 
	instance of Server to get access to crucial server events
	such as receiving requests or responding.

	Make sure to call super on all overridden functions. 
*/
public class Bootstrap {

	///
	public func request(request: Request) {
		Session.start(request)
	}

	public func respond(request: Request, response: Response) {
		Session.close(request: request, response: response)
	}

}