import ballerina/http;
import ballerina/io;
import ballerina/test;
import ballerina/regex;

type Testrun record {
    string projectCode;
    boolean include_all_cases;
    string title;
    int[] cases;
    string Token;
};

configurable Testrun testrun = ?;

// This function creates a new test run in the given project. It returns the id of the created test run.
isolated function createTestRun() returns int|error {
    string baseUrl = "https://api.qase.io/v1/";
    http:Client testrunClient = check new (baseUrl);
    string projectCode = testrun.projectCode;

    json payload = {
        title: testrun.title,
        include_all_cases: testrun.include_all_cases,
        cases: testrun.cases,
        is_autotest: true
    };

    http:Request request = new;
    request.addHeader("Token", testrun.Token);
    request.setJsonPayload(payload);

    http:Response response = check testrunClient->post("/run/" + projectCode, request);

    json responseJson = check response.getJsonPayload();
    if response.statusCode == 200 {
        int id = check responseJson.result.id;
        return id;
    }
    return error("Error while creating test run");
}

// This function writes the bulk of test results to the test run.
isolated function writeTestResults(string path) returns error? {
    string projectCode = testrun.projectCode;
    string baseUrl = "https://api.qase.io/v1/";
    http:Client testrunClient = check new (baseUrl);

    json resultsJson = {};
    int runId = check createTestRun();

    json[] results = check getResults(path) ?: [];

    if results.length() > 0 {
        resultsJson = {
            "results": results
        };

        http:Request request = new;
        request.addHeader("Token", testrun.Token);
        request.setJsonPayload(resultsJson);

        string constructUrl = string `/result/${projectCode}/${runId}/bulk`;

        http:Response response = check testrunClient->post(constructUrl, request);
        json responseJson = check response.getJsonPayload();
        io:println(responseJson);

        io:println(resultsJson.toJson());
    }
}

// This function reads the test results from the json file.
isolated function readJsonData(string filePath) returns map<json> {
    json|error data = io:fileReadJson(filePath);

    if data is map<json> {
        return data;
    } else {
        test:assertFail(string `Can not load data from: ${filePath}`);
    }
}

// This function constructs the json array of test results required for the json payload. 
isolated function getResults(string filePath) returns json[]|error? {
    map<json> results = readJsonData(filePath);

    json|error moduleStatus = results.moduleStatus;

    if moduleStatus is json {
        if moduleStatus is json[] {
            json[] moduleStatusArray = moduleStatus;
            json|error tests = moduleStatusArray[0].tests;

            if tests is json[] {
                json[] testsArray = tests;

                foreach var item in testsArray {
                    if item is map<json> {
                        // It renames the "name" to "case_id".
                        item["case_id"] = item["name"];
                        _ = item.remove("name");

                        // It splits and gets case_id digit.
                        string caseName = item["case_id"].toString();
                        string[] parts = regex:split(caseName, "_");
                        string testcaseId = parts[1];
                        item["case_id"] = testcaseId;

                        //It converts the status to lowercase.
                        item["status"] = item["status"].toString().toLowerAscii();

                        // It constructs the failure scenario by converting 'failure' to 'failed' and removing the 'failureMessage'.
                        if item["status"] == "failure" {
                            item["status"] = "failed";
                            _ = item.remove("failureMessage");
                        }
                    }
                }
                io:println(testsArray);
                return testsArray;

            } else {
                return error("Not a JSON array");
            }
        } else {
            return error("Not a JSON array");
        }
    }
    return;
}
