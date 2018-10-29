import Cocoa

class RenameBranchPanelController: SheetController
{
  @IBOutlet weak var promptLabel: NSTextField!
  @IBOutlet weak var textField: NSTextField!
  
  var branchName: String
  {
    get
    {
      return textField.stringValue
    }
    set
    {
      promptLabel.uiStringValue = .renamePrompt(newValue)
      textField.stringValue = newValue
    }
  }
}

extension RenameBranchPanelController: NSTextFieldDelegate
{
  func controlTextDidChange(_ obj: Notification)
  {
    acceptButton!.isEnabled =
        XTRefFormatter.isValidRefString(textField.stringValue)
  }
}
