package org.fuxuan.classics.core.behavior

import org.fuxuan.classics.core.content.ScriptureContent
import org.fuxuan.classics.core.content.ScriptureSection

data class OutlineDisclosureRow(
    val section: ScriptureSection,
    val depth: Int,
    val hasChildren: Boolean,
    val isExpanded: Boolean,
) {
    init {
        require(depth >= 0) { "outline depth must not be negative" }
        require(!isExpanded || hasChildren) { "only parent sections can be expanded" }
    }
}

object OutlineDisclosurePolicy {
    fun sanitizeExpandedSectionIDs(
        content: ScriptureContent,
        sectionIDs: Set<String>,
    ): Set<String> = sectionIDs.filterTo(linkedSetOf()) { sectionID ->
        content.section(sectionID) != null && content.childrenOf(sectionID).isNotEmpty()
    }

    fun expandableSectionIDs(content: ScriptureContent): Set<String> =
        content.sections
            .asSequence()
            .map(ScriptureSection::sectionID)
            .filter { sectionID -> content.childrenOf(sectionID).isNotEmpty() }
            .toCollection(linkedSetOf())

    fun visibleRows(
        content: ScriptureContent,
        expandedSectionIDs: Set<String>,
    ): List<OutlineDisclosureRow> {
        val expanded = sanitizeExpandedSectionIDs(content, expandedSectionIDs)
        return buildList {
            fun append(section: ScriptureSection, depth: Int) {
                val children = content.childrenOf(section.sectionID)
                val isExpanded = children.isNotEmpty() && section.sectionID in expanded
                add(
                    OutlineDisclosureRow(
                        section = section,
                        depth = depth,
                        hasChildren = children.isNotEmpty(),
                        isExpanded = isExpanded,
                    ),
                )
                if (isExpanded) children.forEach { child -> append(child, depth + 1) }
            }
            content.rootSections().forEach { root -> append(root, depth = 0) }
        }
    }
}
