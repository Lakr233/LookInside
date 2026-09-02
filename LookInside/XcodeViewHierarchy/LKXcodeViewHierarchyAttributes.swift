// LKXcodeViewHierarchyAttributes.swift
//
// Builds the attribute cards the dashboard shows for a node imported from an
// Xcode capture.
//
// A live session answers attribute queries on demand and a `.lookin` archive
// carries the answers on each node; an imported capture has to do the same,
// which is what this file produces. The identifiers are the inspector's own
// (`LookinAttrGroup_*`, `LookinAttrSec_*`, `LookinAttr_*`) so the cards render
// with their normal titles, ordering and editors rather than as anonymous
// key-value rows — with the editors inert, since the document is read-only.
//
// Scope is the geometry and the common visual properties, plus Auto Layout
// sizing. A capture carries hundreds of distinct property names per class;
// mapping all of them is a separate piece of work, and the ones here are the
// ones the preview and the tree already depend on being right.

import AppKit
import Foundation

enum LKXcodeViewHierarchyAttributes {
    /// Builds every attribute group for one captured object.
    ///
    /// `layerNode` is the view's backing layer when it has one: several of the
    /// properties the Layout and View/Layer cards show (position, anchor point,
    /// corner radius, masks to bounds) live on the layer rather than the view.
    static func makingGroups(
        for node: LKXcodeViewHierarchyNode,
        layerNode: LKXcodeViewHierarchyNode?,
        graph: LKXcodeViewHierarchyObjectGraph
    ) -> [LookinAttributesGroup] {
        var groups: [LookinAttributesGroup] = []
        if let classGroup = makingClassGroup(for: node, graph: graph) { groups.append(classGroup) }
        if let layoutGroup = makingLayoutGroup(for: node, layerNode: layerNode) { groups.append(layoutGroup) }
        if let viewLayerGroup = makingViewLayerGroup(for: node, layerNode: layerNode) { groups.append(viewLayerGroup) }
        if let autoLayoutGroup = makingAutoLayoutGroup(for: node) { groups.append(autoLayoutGroup) }
        return groups
    }

    /// The Layout Guide card, which replaces the view cards for guide nodes.
    static func makingLayoutGuideGroups(
        for guideNode: LKXcodeViewHierarchyNode,
        graph: LKXcodeViewHierarchyObjectGraph
    ) -> [LookinAttributesGroup] {
        var sections: [LookinAttributesSection] = []
        if let identifier = guideNode.property(named: "identifier")?.value.textValue, !identifier.isEmpty {
            sections.append(makingSection(
                LookinAttrSec_LayoutGuide_Identifier,
                [makingStringAttribute(LookinAttr_LayoutGuide_Identifier_Identifier, identifier)]
            ))
        }
        if let layoutFrame = rect(from: guideNode, propertyName: "layoutFrame") {
            sections.append(makingSection(
                LookinAttrSec_LayoutGuide_LayoutFrame,
                [makingRectAttribute(LookinAttr_LayoutGuide_LayoutFrame_LayoutFrame, layoutFrame)]
            ))
        }
        guard !sections.isEmpty else { return [] }

        var groups = [makingGroup(LookinAttrGroup_LayoutGuide, sections)]
        if let classGroup = makingClassGroup(for: guideNode, graph: nil) { groups.insert(classGroup, at: 0) }
        return groups
    }

    // MARK: - Cards

    private static func makingClassGroup(
        for node: LKXcodeViewHierarchyNode,
        graph: LKXcodeViewHierarchyObjectGraph?
    ) -> LookinAttributesGroup? {
        guard let className = node.className else { return nil }
        let attribute = makingStringAttribute(LookinAttr_Class_Class_Class, className)
        return makingGroup(LookinAttrGroup_Class, [makingSection(LookinAttrSec_Class_Class, [attribute])])
    }

    private static func makingLayoutGroup(
        for node: LKXcodeViewHierarchyNode,
        layerNode: LKXcodeViewHierarchyNode?
    ) -> LookinAttributesGroup? {
        var sections: [LookinAttributesSection] = []

        if let frame = rect(from: node, propertyName: "frame") ?? rect(from: layerNode, propertyName: "frame") {
            sections.append(makingSection(
                LookinAttrSec_Layout_Frame,
                [makingRectAttribute(LookinAttr_Layout_Frame_Frame, frame)]
            ))
        }
        if let bounds = rect(from: node, propertyName: "bounds") ?? rect(from: layerNode, propertyName: "bounds") {
            sections.append(makingSection(
                LookinAttrSec_Layout_Bounds,
                [makingRectAttribute(LookinAttr_Layout_Bounds_Bounds, bounds)]
            ))
        }
        if let position = point(from: layerNode ?? node, propertyName: "position") {
            sections.append(makingSection(
                LookinAttrSec_Layout_Position,
                [makingPointAttribute(LookinAttr_Layout_Position_Position, position)]
            ))
        }
        if let anchorPoint = point(from: layerNode ?? node, propertyName: "anchorPoint") {
            sections.append(makingSection(
                LookinAttrSec_Layout_AnchorPoint,
                [makingPointAttribute(LookinAttr_Layout_AnchorPoint_AnchorPoint, anchorPoint)]
            ))
        }

        guard !sections.isEmpty else { return nil }
        return makingGroup(LookinAttrGroup_Layout, sections)
    }

    private static func makingViewLayerGroup(
        for node: LKXcodeViewHierarchyNode,
        layerNode: LKXcodeViewHierarchyNode?
    ) -> LookinAttributesGroup? {
        var sections: [LookinAttributesSection] = []

        var visibilityAttributes: [LookinAttribute] = []
        if let hidden = node.property(named: "hidden")?.value.boolValue
            ?? layerNode?.property(named: "hidden")?.value.boolValue {
            visibilityAttributes.append(makingBoolAttribute(LookinAttr_ViewLayer_Visibility_Hidden, hidden))
        }
        if let opacity = node.property(named: "alpha")?.value.doubleValue
            ?? layerNode?.property(named: "opacity")?.value.doubleValue {
            visibilityAttributes.append(makingFloatAttribute(LookinAttr_ViewLayer_Visibility_Opacity, opacity))
        }
        if !visibilityAttributes.isEmpty {
            sections.append(makingSection(LookinAttrSec_ViewLayer_Visibility, visibilityAttributes))
        }

        if let backgroundColor = colorComponents(from: layerNode ?? node, propertyName: "backgroundColor") {
            sections.append(makingSection(
                LookinAttrSec_ViewLayer_BgColor,
                [makingColorAttribute(LookinAttr_ViewLayer_BgColor_BgColor, backgroundColor)]
            ))
        }

        if let cornerRadius = (layerNode ?? node).property(named: "cornerRadius")?.value.doubleValue {
            sections.append(makingSection(
                LookinAttrSec_ViewLayer_Corner,
                [makingFloatAttribute(LookinAttr_ViewLayer_Corner_Radius, cornerRadius)]
            ))
        }

        var borderAttributes: [LookinAttribute] = []
        if let borderWidth = (layerNode ?? node).property(named: "borderWidth")?.value.doubleValue {
            borderAttributes.append(makingFloatAttribute(LookinAttr_ViewLayer_Border_Width, borderWidth))
        }
        if let borderColor = colorComponents(from: layerNode ?? node, propertyName: "borderColor") {
            borderAttributes.append(makingColorAttribute(LookinAttr_ViewLayer_Border_Color, borderColor))
        }
        if !borderAttributes.isEmpty {
            sections.append(makingSection(LookinAttrSec_ViewLayer_Border, borderAttributes))
        }

        if let masksToBounds = (layerNode ?? node).property(named: "masksToBounds")?.value.boolValue {
            sections.append(makingSection(
                LookinAttrSec_ViewLayer_InterationAndMasks,
                [makingBoolAttribute(LookinAttr_ViewLayer_InterationAndMasks_MasksToBounds, masksToBounds)]
            ))
        }

        guard !sections.isEmpty else { return nil }
        return makingGroup(LookinAttrGroup_ViewLayer, sections)
    }

    /// Auto Layout sizing. The constraint list itself is a richer structure
    /// than these cards take, so only the per-view sizing values are mapped.
    private static func makingAutoLayoutGroup(for node: LKXcodeViewHierarchyNode) -> LookinAttributesGroup? {
        var sections: [LookinAttributesSection] = []

        var huggingAttributes: [LookinAttribute] = []
        if let horizontal = node.property(named: "contentHuggingPriorityHorizontal")?.value.doubleValue {
            huggingAttributes.append(makingFloatAttribute(LookinAttr_AutoLayout_Hugging_Hor, horizontal))
        }
        if let vertical = node.property(named: "contentHuggingPriorityVertical")?.value.doubleValue {
            huggingAttributes.append(makingFloatAttribute(LookinAttr_AutoLayout_Hugging_Ver, vertical))
        }
        if !huggingAttributes.isEmpty {
            sections.append(makingSection(LookinAttrSec_AutoLayout_Hugging, huggingAttributes))
        }

        var resistanceAttributes: [LookinAttribute] = []
        if let horizontal = node.property(named: "contentCompressionResistancePriorityHorizontal")?.value.doubleValue {
            resistanceAttributes.append(makingFloatAttribute(LookinAttr_AutoLayout_Resistance_Hor, horizontal))
        }
        if let vertical = node.property(named: "contentCompressionResistancePriorityVertical")?.value.doubleValue {
            resistanceAttributes.append(makingFloatAttribute(LookinAttr_AutoLayout_Resistance_Ver, vertical))
        }
        if !resistanceAttributes.isEmpty {
            sections.append(makingSection(LookinAttrSec_AutoLayout_Resistance, resistanceAttributes))
        }

        if let intrinsicSize = size(from: node, propertyName: "intrinsicContentSize") {
            sections.append(makingSection(
                LookinAttrSec_AutoLayout_IntrinsicSize,
                [makingSizeAttribute(LookinAttr_AutoLayout_IntrinsicSize_Size, intrinsicSize)]
            ))
        }

        guard !sections.isEmpty else { return nil }
        return makingGroup(LookinAttrGroup_AutoLayout, sections)
    }

    // MARK: - Value readers

    private static func rect(from node: LKXcodeViewHierarchyNode?, propertyName: String) -> CGRect? {
        guard let components = node?.property(named: propertyName)?.value.numericComponents(expectedCount: 4)
        else { return nil }
        return CGRect(x: components[0], y: components[1], width: components[2], height: components[3])
    }

    private static func point(from node: LKXcodeViewHierarchyNode?, propertyName: String) -> CGPoint? {
        guard let components = node?.property(named: propertyName)?.value.numericComponents(expectedCount: 2)
        else { return nil }
        return CGPoint(x: components[0], y: components[1])
    }

    private static func size(from node: LKXcodeViewHierarchyNode?, propertyName: String) -> CGSize? {
        guard let components = node?.property(named: propertyName)?.value.numericComponents(expectedCount: 2)
        else { return nil }
        return CGSize(width: components[0], height: components[1])
    }

    /// RGBA in 0...1, which is what a `LookinAttrTypeUIColor` value carries
    /// (`LookinAttrType.h`). The dashboard decodes that array itself and
    /// asserts on anything else, so no `NSColor` is built here.
    private static func colorComponents(
        from node: LKXcodeViewHierarchyNode?,
        propertyName: String
    ) -> [NSNumber]? {
        guard case .color(let captured)? = node?.property(named: propertyName)?.value,
              captured.components.count >= 3
        else { return nil }
        let alpha = captured.components.count >= 4 ? captured.components[3] : 1
        return [captured.components[0], captured.components[1], captured.components[2], alpha]
            .map { NSNumber(value: $0) }
    }

    // MARK: - Builders

    private static func makingGroup(
        _ identifier: String,
        _ sections: [LookinAttributesSection]
    ) -> LookinAttributesGroup {
        let group = LookinAttributesGroup()
        group.identifier = identifier
        group.attrSections = sections
        return group
    }

    private static func makingSection(
        _ identifier: String,
        _ attributes: [LookinAttribute]
    ) -> LookinAttributesSection {
        let section = LookinAttributesSection()
        section.identifier = identifier
        section.attributes = attributes
        return section
    }

    private static func makingAttribute(
        _ identifier: String,
        _ attrType: LookinAttrType,
        _ value: Any
    ) -> LookinAttribute {
        let attribute = LookinAttribute()
        attribute.identifier = identifier
        attribute.attrType = attrType
        attribute.value = value
        return attribute
    }

    private static func makingStringAttribute(_ identifier: String, _ value: String) -> LookinAttribute {
        makingAttribute(identifier, .nsString, value as NSString)
    }

    private static func makingBoolAttribute(_ identifier: String, _ value: Bool) -> LookinAttribute {
        makingAttribute(identifier, .BOOL, NSNumber(value: value))
    }

    private static func makingFloatAttribute(_ identifier: String, _ value: Double) -> LookinAttribute {
        makingAttribute(identifier, .float, NSNumber(value: value))
    }

    private static func makingRectAttribute(_ identifier: String, _ value: CGRect) -> LookinAttribute {
        makingAttribute(identifier, .cgRect, NSValue(rect: value))
    }

    private static func makingPointAttribute(_ identifier: String, _ value: CGPoint) -> LookinAttribute {
        makingAttribute(identifier, .cgPoint, NSValue(point: value))
    }

    private static func makingSizeAttribute(_ identifier: String, _ value: CGSize) -> LookinAttribute {
        makingAttribute(identifier, .cgSize, NSValue(size: value))
    }

    private static func makingColorAttribute(_ identifier: String, _ components: [NSNumber]) -> LookinAttribute {
        makingAttribute(identifier, .uiColor, components as NSArray)
    }
}
