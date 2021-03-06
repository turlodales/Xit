import XCTest
@testable import Xit

extension XTTest.FileName
{
  static let blame = "elements.txt"
}

class BlameTest: XTTest
{
  let elements1 = ["Antimony",
                   "Arsenic",
                   "Aluminum",
                   "Selenium",
                   "Hydrogen",
                   "Oxygen",
                   "Nitrogen",
                   "Rhenium"]
  let elements2 = ["Antimony",
                   "Arsenic",
                   "Aluminum**",
                   "Selenium**",
                   "Hydrogen",
                   "Oxygen",
                   "Nitrogen",
                   "Rhenium"]
  let elements3 = ["Antimony",
                   "Arsenic",
                   "Aluminum**",
                   "Selenium**",
                   "Hydrogen++",
                   "Oxygen",
                   "Nitrogen",
                   "Rhenium"]
  var blamePath: String!

  func commit(lines: [String], message: String)
  {
    let text = lines.joined(separator: "\n")
    
    try! text.write(toFile: blamePath, atomically: true, encoding: .ascii)
    try! repository.stage(file: FileName.blame)
    try! repository.commit(message: message, amend: false)
  }
  
  override func setUp()
  {
    super.setUp()
    
    blamePath = repository.repoURL.path.appending(pathComponent: FileName.blame)
    commit(lines: elements1, message: "first")
    commit(lines: elements2, message: "second")
    commit(lines: elements3, message: "third")
  }
  
  func testCommitBlame() throws
  {
    let headSHA = try XCTUnwrap(repository.headSHA)
    let headCommit = try XCTUnwrap(GitCommit(sha: headSHA, repository: repository.gitRepo))
    let headOID = try XCTUnwrap(GitOID(sha: headSHA))
    let commitModel = CommitSelection(repository: repository,
                                    commit: headCommit)
    let commitBlame = try XCTUnwrap(commitModel.fileList.blame(for: FileName.blame))
    let lineStarts = [1, 3, 5, 6]
    let lineCounts = [2, 2, 1, 3]
    
    XCTAssertEqual(commitBlame.hunks.count, 4)
    XCTAssertEqual(commitBlame.hunks.map { $0.finalLine.start }, lineStarts)
    XCTAssertEqual(commitBlame.hunks.map { $0.lineCount }, lineCounts)
    XCTAssertEqual(commitBlame.hunks[2].finalLine.oid as! GitOID, headOID)
  }
  
  func testStagingBlame() throws
  {
    var elements4 = elements3
    
    elements4[0].append("!!")
    
    let fourthLines = elements4.joined(separator: "\n")
    
    try fourthLines.write(toFile: blamePath, atomically: true, encoding: .ascii)
    try repository.stageAllFiles()
    
    var elements5 = elements4
    
    elements5[7].append("##")
    
    let fifthLines = elements5.joined(separator: "\n")
    
    try fifthLines.write(toFile: blamePath, atomically: true, encoding: .ascii)

    let stagingModel = StagingSelection(repository: repository)
    let unstagedBlame = try XCTUnwrap(stagingModel.unstagedFileList.blame(for: FileName.blame),
                                      "can't get unstaged blame")
    let unstagedStarts = [1, 2, 3, 5, 6, 8]
    
    XCTAssertEqual(unstagedBlame.hunks.count, 6)
    XCTAssertEqual(unstagedBlame.hunks.map { $0.finalLine.start }, unstagedStarts)
    XCTAssertTrue(unstagedBlame.hunks.first?.finalLine.oid.isZero ?? false)
    XCTAssertTrue(unstagedBlame.hunks.last?.finalLine.oid.isZero ?? false)
    
    let stagedBlame = try XCTUnwrap(stagingModel.fileList.blame(for: FileName.blame),
                                    "can't get staged blame")
    let stagedStarts = [1, 2, 3, 5, 6]
    
    XCTAssertEqual(stagedBlame.hunks.count, 5)
    XCTAssertEqual(stagedBlame.hunks.map { $0.finalLine.start }, stagedStarts)
    XCTAssertTrue(stagedBlame.hunks.first?.finalLine.oid.isZero ?? false)
  }
}
