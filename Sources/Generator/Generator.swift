class Generator {
    var parameterMax: Int

    init(max parameters: Int) {
        parameterMax = parameters
    }

    func generate() {
        let permutations = generatePermutations()

        var functions: [Function] = []

        for parameters in permutations {
            if parameters.count == 0 {
                continue
            }

            let function = Function(variant: .socket, method: .get, parameters: parameters)
            functions.append(function)

            for method: Method in [.get, .post, .put, .patch, .delete, .options] {
                let function = Function(variant: .base, method: method, parameters: parameters)
                functions.append(function)
            }
        }

        for function in functions {
            print(function)
        }
    }

    private func generatePermutations() -> [[Parameter]] {
        var permutations: [[Parameter]] = [[]]

        for i in 0 ... parameterMax {
            var subPermutations: [[Parameter]] = [[]]

            for _ in 0 ..< i {
                subPermutations = permutate(subPermutations)
            }

            permutations += subPermutations
        }
        
        return permutations
    }


    private func permutate(_ array: [[Parameter]]) -> [[Parameter]] {
        var result: [[Parameter]] = []

        for subarray in array {
            var pathArray = subarray
            var wildcardArray = subarray

            let path = Parameter.pathFor(pathArray)
            pathArray.append(path)

            let wildcard = Parameter.wildcardFor(wildcardArray)
            wildcardArray.append(wildcard)

            result.append(pathArray)
            result.append(wildcardArray)
        }
        
        return result
    }

}
