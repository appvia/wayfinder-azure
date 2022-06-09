# Working on the Azure ARM Templates

Here be general notes on working with Wayfinder's Azure Marketplace ARM templates.

## Developer tooling
The marketplace configuration uses Azure's ARM (Azure Resource Manager) templates, which are specified via JSON.

If using VS Code, it's recommended to install the [Azure Resource Manager Tools](https://marketplace.visualstudio.com/items?itemName=msazurermtools.azurerm-vscode-tools) extension, which provides a language server, schema validation, snippets and other goodies to help write ARM templates.

## Validating Template changes

If making changes to the ARM templates, run the test suite in the ARM Template Testing Toolkit to make sure the templates are valid and unlikely to have issues when being submitted to the Marketplace. See [here]() for more details on the toolkit tests, but to run the tests you will need to have PowerShell installed, and the toolkit downloaded so the relevant modules can be imported into PowerShell:

### Download Powershell

On MacOS, the simplest way to install PowerShell is via `brew`:

```shell
$ brew install --cask powershell
```

And from here, `pwsh` will fork a new PowerShell process.

>For other platforms, see [here](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.2).


### Download the testing toolkit

The ARM Template Testing Toolkit (ttk) can be downloaded [here](https://aka.ms/arm-ttk-latest) - it just needs to be downloaded and unzipped somewhere sensible.

More information about the toolkit can be found at https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/test-toolkit

### Run the tests

Running the tests is straightforward. Ensure you are in the PowerShell (`pwsh` from Bash and friends), and in the `wayfinder-azure/arm-template` directory, then:

```powershell
# Import the testing module into PowerShell
PS /Path/To/wayfinder-azure/arm-tamplate> Import-Module </Path/To/testing/toolkit>/arm-ttk/arm-ttk.psd1
# Run the toolkit tests
PS /Path/To/wayfinder-azure/arm-tamplate> Test-AzTemplate -TemplatePath .
```