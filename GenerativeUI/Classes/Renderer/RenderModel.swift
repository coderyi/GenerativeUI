import Foundation

/// An intermediate render section, mapping `section` components or the root level.
struct RenderSection {
    let id: String
    let title: String?
    let items: [RenderItem]
}

/// An intermediate render item, wrapping a single component spec.
struct RenderItem: Hashable {
    let componentId: String
    let component: ComponentSpec

    func hash(into hasher: inout Hasher) {
        hasher.combine(componentId)
    }

    static func == (lhs: RenderItem, rhs: RenderItem) -> Bool {
        lhs.componentId == rhs.componentId
    }
}

/// Transforms a `ScreenSpec` into an intermediate render model for `UICollectionView`.
enum RenderModelBuilder {

    /// Builds render sections from a screen spec.
    /// - Top-level `section` components become their own `RenderSection`.
    /// - Top-level non-section components are grouped into an implicit default section.
    static func build(from spec: ScreenSpec) -> [RenderSection] {
        var sections: [RenderSection] = []
        var pendingItems: [RenderItem] = []

        for component in spec.components {
            if component.type == ComponentType.section.rawValue {
                // Flush any pending non-section items as an implicit section
                if !pendingItems.isEmpty {
                    sections.append(RenderSection(id: "__implicit_\(sections.count)", title: nil, items: pendingItems))
                    pendingItems = []
                }
                // Section component: children become items
                var sectionItems: [RenderItem] = []
                if let children = component.children {
                    for child in children {
                        sectionItems.append(RenderItem(componentId: child.id, component: child))
                    }
                }
                sections.append(RenderSection(
                    id: component.id,
                    title: component.props["title"]?.stringValue,
                    items: sectionItems
                ))
            } else {
                pendingItems.append(RenderItem(componentId: component.id, component: component))
            }
        }

        // Flush remaining non-section items
        if !pendingItems.isEmpty {
            sections.append(RenderSection(id: "__implicit_\(sections.count)", title: nil, items: pendingItems))
        }

        return sections
    }
}
