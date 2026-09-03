import XCTest
@testable import Ascend

final class MarkdownAttachmentPolicyTests: XCTestCase {
    func testRemoteMarkdownImagesAreRejected() throws {
        let root = URL(fileURLWithPath: "/tmp/notes", isDirectory: true)
        let remoteURL = try XCTUnwrap(URL(string: "https://example.invalid/private-note-image.png"))

        XCTAssertNil(MarkdownAttachmentPolicy.localImageURL(for: remoteURL, relativeTo: root))
    }

    func testRelativeMarkdownImageResolvesInsideNoteDirectory() throws {
        let root = URL(fileURLWithPath: "/tmp/notes", isDirectory: true)
        let reference = try XCTUnwrap(URL(string: "images/diagram.png"))

        XCTAssertEqual(
            MarkdownAttachmentPolicy.localImageURL(for: reference, relativeTo: root)?.path,
            "/tmp/notes/images/diagram.png"
        )
    }

    func testMarkdownImageCannotEscapeNoteDirectory() throws {
        let root = URL(fileURLWithPath: "/tmp/notes", isDirectory: true)
        let reference = try XCTUnwrap(URL(string: "../secret.png"))

        XCTAssertNil(MarkdownAttachmentPolicy.localImageURL(for: reference, relativeTo: root))
    }
}
