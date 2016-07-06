import Cocoa


enum AccountType : Int {
  case GitHub = 0
  case BitBucket = 1
  case TeamCity = 2
  
  init?(name: String?)
  {
    guard name != nil else { return nil }
    
    switch name! {
    case "github":
      self = .GitHub
    case "bitbucket":
      self = .BitBucket
    case "teamcity":
      self = .TeamCity
    default:
      return nil
    }
  }
  
  var name: String
  {
    switch self {
    case .GitHub: return "github"
    case .BitBucket: return "bitbucket"
    case .TeamCity: return "teamcity"
    }
  }
  
  var displayName: String
  {
    switch self {
    case .GitHub: return "GitHub"
    case .BitBucket: return "BitBucket"
    case .TeamCity: return "TeamCity"
    }
  }
  
  var defaultLocation: String
  {
    switch self {
    case .GitHub: return "https://api.github.com"
    case .BitBucket: return "https://api.bitbucket.org"
    case .TeamCity: return ""
    }
  }
  
  var imageName: String
  {
    switch self {
    case .GitHub: return "githubTemplate"
    case .BitBucket: return "bitbucketTemplate"
    case .TeamCity: return "teamcityTemplate"
    }
  }
}


struct Account {
  var type: AccountType
  var user: String
  var location: NSURL
}


class XTAccountsManager: NSObject {
  
  /// Account types as stored in preferences
  let userKey = "user"
  let locationKey = "location"
  let typeKey = "type"

  static let manager = XTAccountsManager()
  
  var accounts: [Account] = []
  
  func add(account: Account)
  {
    accounts.append(account)
  }
  
  func readAccounts()
  {
    guard let storedAccounts =
      NSUserDefaults.standardUserDefaults().arrayForKey("accounts")
        as? [[String: AnyObject]]
      else { return }
    
    for accountDict in storedAccounts {
      if let type = AccountType(name: accountDict[typeKey] as? String),
        let user = accountDict[userKey] as? String,
        let locationString = accountDict[locationKey] as? String,
        let location = NSURL(string: locationString) {
        accounts.append(Account(type: type, user: user, location: location))
      }
      else {
        NSLog("Couldn't read account: \(accountDict.description)")
      }
    }
  }
  
  func saveAccounts()
  {
    let accountsList = NSMutableArray(capacity: accounts.count)
    
    for account in accounts {
      let accountDict = NSMutableDictionary(capacity: 3)
      
      accountDict[typeKey] = account.type.name
      accountDict[userKey] = account.user
      accountDict[locationKey] = account.location.absoluteString
      accountsList.addObject(accountDict)
    }
    NSUserDefaults.standardUserDefaults().setValue(accountsList,
                                                   forKey: "accounts")
  }
  
}
