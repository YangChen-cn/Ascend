import AppKit
import SwiftUI
import Textual

/// Single integration boundary for Markdown rendering across the app.
struct LocalMarkdownDocumentView: View {
    let source: String
    let baseURL: URL?

    var body: some View {
        StructuredText(markdown: source, baseURL: baseURL)
            .textual.structuredTextStyle(.gitHub)
            .textual.overflowMode(.scroll)
            .textual.textSelection(.enabled)
            .textual.imageAttachmentLoader(LocalMarkdownImageLoader(baseURL: baseURL))
            .font(.system(size: 14))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Resolves only images inside the currently previewed note directory.
/// Network URLs and paths escaping through `..` or symlinks are rejected before I/O.
struct LocalMarkdownImageLoader: AttachmentLoader {
    let baseURL: URL?

    func attachment(
        for url: URL,
        text: String,
        environment _: ColorEnvironmentValues
    ) async throws -> LocalMarkdownImageAttachment {
        guard let fileURL = MarkdownAttachmentPolicy.localImageURL(for: url, relativeTo: baseURL) else {
            throw MarkdownAttachmentError.disallowedURL
        }

        let data = try await Task.detached(priority: .utility) {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let byteCount = (attributes[.size] as? NSNumber)?.intValue ?? 0
            guard byteCount <= MarkdownAttachmentPolicy.maximumImageBytes else {
                throw MarkdownAttachmentError.imageTooLarge
            }
            return try Data(contentsOf: fileURL, options: .mappedIfSafe)
        }.value

        guard let image = NSImage(data: data), image.size.width > 0, image.size.height > 0 else {
            throw MarkdownAttachmentError.invalidImage
        }

        return LocalMarkdownImageAttachment(
            data: data,
            altText: text,
            intrinsicSize: image.size
        )
    }
}

struct LocalMarkdownImageAttachment: Attachment {
    let data: Data
    let altText: String
    let intrinsicSize: CGSize

    var description: String { altText }

    @MainActor var body: some View {
        Group {
            if let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel(altText)
            } else {
                Text(altText)
            }
        }
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        in _: TextEnvironmentValues
    ) -> CGSize {
        guard let proposedWidth = proposal.width, intrinsicSize.width > proposedWidth else {
            return intrinsicSize
        }
        let aspectRatio = intrinsicSize.width / intrinsicSize.height
        return CGSize(width: proposedWidth, height: proposedWidth / aspectRatio)
    }
}

enum MarkdownAttachmentPolicy {
    static let maximumImageBytes = 12 * 1_024 * 1_024

    static func localImageURL(for reference: URL, relativeTo baseURL: URL?) -> URL? {
        guard let baseURL, baseURL.isFileURL else { return nil }

        let root = baseURL.standardizedFileURL.resolvingSymlinksInPath()
        let candidate: URL
        if reference.isFileURL {
            candidate = reference
        } else if reference.scheme == nil {
            candidate = URL(fileURLWithPath: reference.relativeString, relativeTo: root)
        } else {
            return nil
        }

        let resolved = candidate.standardizedFileURL.resolvingSymlinksInPath()
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard resolved.path == root.path || resolved.path.hasPrefix(rootPath) else { return nil }
        return resolved
    }
}

enum MarkdownAttachmentError: Error {
    case disallowedURL
    case imageTooLarge
    case invalidImage
}
