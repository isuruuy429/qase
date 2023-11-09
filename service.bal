import ballerina/http;

service /qase on new http:Listener(9090) { 
    
   isolated resource function get testrun() returns int|error{
        return createTestRun();
    }

    isolated resource function get results(string path) returns error?{
        return writeTestResults(path);
    }
}                   
