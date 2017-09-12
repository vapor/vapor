# Code Quality manifesto

Code quality needs to be ensured for every project. Projects the size of Vapor, however, need strict checks to ensure there is little to no quality regression.

This manifesto is designed as a base line for code quality in all official Vapor projects.

## What defines quality code?

Code quality is a very broad term that can mean many things. Definitions differ per person. For this reason, we define the following as quality code:

**Unit tests:**

- An absolute minimum of 80% test coverage
- When critical code is dependent on random factors, these random factors will be simulated to the extend possible

**Structure:**

- Complex programs need to be split up into multiple files as much as is sensible to keep files comprehensible

**Inline documentation:**

- A minimum of 80% inline documentation for publically exposed functionality
- Critical objects to the library and it's consumers needs a more thorough explaination of the functionality

**Tutorials:**

Tutorials are defined as example code with explaination.

- An absolute minimum of 70% tutorial coverage of all public objects
- All modules' critical components are 100% covered in tutorials

**API design:**

- APIs and functionalities that are required by a library should be internal until there's little to no doubt the API needs to change for this version of the library

**Readme:**

README.md files **must** contain at least:

- A short description of what the library does
- Some _basic_ usage examples
