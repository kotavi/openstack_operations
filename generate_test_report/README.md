# Generate cloud validation test report

#### Preconditions

`pip install bs4`

#### Provide config.ini

Manually add information into the appropriate sections.
List of sections:

**TitlePage** - information about project. Section is required. 
Keys in the section may not have values, if one of the keys is missing script will return warning message.
 - *CustomerName*
 - *ProjectName*
 - *Date*
 - *Version*
 - *Authors* - new author entry should go to the next line with indentation
 
**Conclusion** - additional information for conclusion part, will be added to the html document to the 'Conclusion' section. 
Key names in this section are fixed, must not be changed.
 - *ExecutedTests* - list of tests that were executed during cloud validation process, new item of the list goes to the next line with indentation;
 - *ConclusionText* - Conclusion or summary about testing results, new line of the text goes to the next line with indentation;
 - *Result* - The value should be <span style="color:green">**READY**</span> or <span style="color:red">**NOT READY**</span>.

**Issues** - information for table with issues that were found during testing. 
Each issue must have 4 lines: issue number/name; severity; summary; comments. 
Instead of empty line use dash ('-'). If there are no issues then this section can be empty.
*Example:*
```
Issue1: issue number/name
    severity
    summary
    comments
```

**DeploymentOverview** - information for table with deployment information. This section can be empty.
Rule for this section is:
```
Component: Configuration

Component goes to column1, Configuration - to column2.
```

**PluginComponentOverview** - information for table with plugins and components. This section can be empty. 
Rule for this section is:
```
Plugin/Component name: Version

Plugin/Component name goes to column1, Version - to column2.
```

**CustomerSpecificExtensions** - additional information about plugins that was not specified in *PluginComponentOverview* section.
This section can be empty. Rule for this section is:
```
Component: Extension

Component goes to column1, Extension - to column2.

```

**SolutionTestStatus** - this is for table in *Test Result Details* in html template. Here you can use any name of the key.
This section can be empty. Rule for this section is:
```
Any_key_name: Solution Feature / Requirement Tested
        How tested (Rally, Templest, OSTF, etc)
        Status (ACCEPTED/NOT ACCEPTED)
        Comments
```

**ExitCriteria** - this is for table in *Test Result Details* in html template. Here you can use any name of the key.
This section can be empty. Rule for this section is:
```
Criterion_name: Criterion
        Status (Yes/No)
        Comment
```

**OSTF** - test results for OSTF. Key names in this section are fixed, must not be changed.
If this type of tests was not performed the section should be removed from config file.
 - *TestOwner*
 - *TestDate*
 - *Filepath*
 - *Summary* - *optional field where you can summarize results of testing*

**SkippedFailedOSTF** - table for failed/skipped tests for OSTF with explanations. 
You should remove this section if there are no skipped or failed tests
Section consists of two parts: Description (optional field) and list of failed/skipped tests.
Example:

```
Description: The table of skipped and failed tests:
Test1: Area (Neutron, Cinder, etc)
    Test ID & Description
    Result (Fail/Skip)
    Comments
```

**Tempest** - test results for Tempest. Key names in this section are fixed, must not be changed.
If this type of tests was not performed the section should be removed from config file.
 - *TestOwner*
 - *TestDate*
 - *Filepath*
 - *Summary* - *optional field where you can summarize results of testing*

**SkippedFailedTempest** - table for failed/skipped tests for Tempest with explanations. 
You should remove this section if there are no skipped or failed tests
Section consists of two parts: Description (optional field) and list of failed/skipped tests.
Example:

```
Description: The table of skipped and failed tests:
Test1: Area (Neutron, Cinder, etc)
    Test ID & Description
    Result (Fail/Skip)
    Comments
```

**HA** - test results for HA. Key names in this section are fixed, must not be changed.
If this type of tests was not performed the section should be removed from config file.
 - *TestOwner*
 - *TestDate*
 - *Filepath*
 - *Summary* - *optional field where you can summarize results of testing*

**SkippedFailedHA** - table for failed/skipped tests for HA with explanations. 
You should remove this section if there are no skipped or failed tests
Section consists of two parts: Description (optional field) and list of failed/skipped tests.
Example:

```
Description: The table of skipped and failed tests:
Test1: Area (Neutron, Cinder, etc)
    Test ID & Description
    Result (Fail/Skip)
    Comments
```
 
**SPT** - test results for simplified performance testing. Key names in this section are fixed, must not be changed.
If this type of tests was not performed the section should be removed from config file.
 - *TestOwner*
 - *TestDate*
 - *Filepath*
 - *Summary* - *optional field where you can summarize results of testing*

**SkippedFailedSPT** - table for failed/skipped tests for SPT with explanations. 
You should remove this section if there are no skipped or failed tests
Section consists of two parts: Description (optional field) and list of failed/skipped tests.
Example:

```
Description: The table of skipped and failed tests:
Test1: Area (Neutron, Cinder, etc)
    Test ID & Description
    Result (Fail/Skip)
    Comments
```

**Manual** - test results for any manual tests performed. Key names in this section are fixed, must not be changed.
If this type of tests was not performed the section should be removed from config file.
 - *TestOwner*
 - *TestDate*
 - *Filepath*
 - *Summary* - *optional field where you can summarize results of testing*

**SkippedFailedManual** - table for failed/skipped tests for Manual with explanations. 
You should remove this section if there are no skipped or failed tests
Section consists of two parts: Description (optional field) and list of failed/skipped tests.
Example:

```
Description: The table of skipped and failed tests:
Test1: Area (Neutron, Cinder, etc)
    Test ID & Description
    Result (Fail/Skip)
    Comments
```
 
**Rally** - test results for Rally. Key names in this section are fixed, must not be changed.
If this type of tests was not performed the section should be removed from config file.
 - *TestOwner*
 - *TestDate*
 - *Filepath*
 - *Summary* - *optional field where you can summarize results of testing*

**SkippedFailedRally** - table for failed/skipped tests for Rally with explanations. 
You should remove this section if there are no skipped or failed tests
Section consists of two parts: Description (optional field) and list of failed/skipped tests.
Example:

```
Description: The table of skipped and failed tests:
Test1: Area (Neutron, Cinder, etc)
    Test ID & Description
    Result (Fail/Skip)
    Comments
```

**Software** - information about software that was used during the testing.
Here you can use any name of the key. Key SoftwareVersions should not be removed even if it does not have any values.
Example:
```
SoftwareVersions: Software name Version;
                  Software name Version;
```

**TestTools** - information about the tools used during the testing.  Here you can use any name of the key.
If there are no "TestTools" then the section should me empty.
Example:
```
TestTools1: Tool name
            Version
            Test Type
            Tool Configuration
```

#### Test reports

After execution of Rally, Tempest, SPT, etc copy their reports to the folder `test_results`. Use specified formats:
- *Rally* - xml format
- *Tempest* - json format
- *SPT* - copy as is in file
- *HA* - paste result in the json (example test_results/ha.json)
- *manual* - paste result in the json (example test_results/manual.json)
- *OSTF* - paste result in the json (example test_results/ostf.json)

#### Generate final report

Execute command:

`./generate_report.py`

As a result `final_test_report.html` will be generated.

Open this file in a browser and save it as `pdf`.

#### Combine pdf files

##### Precondition

```
pip install PyPDF2
```

##### How to execute

```
python combine_pdfs.py  --files_list <path_to_pdf_file_1> <path_to_pdf_file_2> ... <path_to_pdf_file_N> --output <path_to_combined_pdf_file>

python combine_pdfs.py  --files_list pdfs/report.pdf pdfs/Fuel.pdf --output templates/result_file.pdf

```