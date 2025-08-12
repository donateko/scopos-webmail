import 'dart:collection';

import 'package:jmap_dart_client/jmap/mail/mailbox/mailbox.dart';
import 'package:model/extensions/presentation_mailbox_extension.dart';
import 'package:model/mailbox/expand_mode.dart';
import 'package:model/mailbox/mailbox_state.dart';
import 'package:model/mailbox/presentation_mailbox.dart';
import 'package:model/mailbox/select_mode.dart';

import 'mailbox_node.dart';
import 'mailbox_tree.dart';

class TreeBuilder {
  Future<MailboxTree> generateMailboxTree(List<PresentationMailbox> mailboxesList) async {
    final Map<MailboxId, MailboxNode> mailboxDictionary = HashMap();

    final tree = MailboxTree(MailboxNode.root());
    for (var mailbox in mailboxesList) {
      mailboxDictionary[mailbox.id] = MailboxNode(mailbox);
    }
    for (var mailbox in mailboxesList) {
      final node = mailboxDictionary[mailbox.id];
      if (node == null) continue;

      final parentId = mailbox.parentId;
      final parentNode = mailboxDictionary[parentId];
      if (parentNode != null) {
        parentNode.addChildNode(node);
        sortByMailboxNameNodeChildren(parentNode);
      } else {
        tree.root.addChildNode(node);
        sortByMailboxNameNodeChildren(tree.root);
      }
    }
    return tree;
  }

  Future<({
    List<PresentationMailbox> allMailboxes,
    MailboxTree defaultTree,
    MailboxTree personalTree,
    MailboxTree teamMailboxTree
  })> generateMailboxTreeInUI({
    required List<PresentationMailbox> allMailboxes,
    required MailboxTree currentDefaultTree,
    required MailboxTree currentPersonalTree,
    required MailboxTree currentTeamMailboxTree,
    MailboxId? mailboxIdSelected,
  }) async {
    final Map<MailboxId, MailboxNode> mailboxDictionary = HashMap();

    final newDefaultTree = MailboxTree(MailboxNode.root());
    final newPersonalTree = MailboxTree(MailboxNode.root());
    final newTeamMailboxTree = MailboxTree(MailboxNode.root());
  
    final List<PresentationMailbox> newAllMailboxes = <PresentationMailbox>[];

    for (var mailbox in allMailboxes) {
      final currentMailboxNode = findExistingNode(
        id: mailbox.id,
        currentDefaultTree: currentDefaultTree,
        currentPersonalTree: currentPersonalTree,
        currentTeamMailboxTree: currentTeamMailboxTree,
      );

      final isDeactivated = mailbox.id == mailboxIdSelected;
      
      // Override sortOrder for special mailboxes to ensure correct ordering
      final modifiedMailbox = _overrideSortOrderForSpecialMailboxes(mailbox);
      
      final newMailboxNode = MailboxNode(
        isDeactivated ? modifiedMailbox.withMailboxSate(MailboxState.deactivated) : modifiedMailbox,
        nodeState: isDeactivated ? MailboxState.deactivated : MailboxState.activated,
        expandMode: currentMailboxNode?.expandMode ?? ExpandMode.COLLAPSE,
        selectMode: currentMailboxNode?.selectMode ?? SelectMode.INACTIVE,
      );

      mailboxDictionary[mailbox.id] = newMailboxNode;
    }

    for (var mailbox in allMailboxes) {
      final currentNode = mailboxDictionary[mailbox.id];
      if (currentNode == null) continue;

      final parentId = mailbox.parentId;
      final parentNode = parentId != null ? mailboxDictionary[parentId] : null;

      if (parentNode != null) {
        if (parentNode.nodeState == MailboxState.deactivated) {
          currentNode.updateItem(mailbox.withMailboxSate(MailboxState.deactivated));
          currentNode.updateNodeState(MailboxState.deactivated);
        }
        parentNode.addChildNode(currentNode);

        sortByMailboxNameNodeChildren(parentNode);
      } else {
        final targetTree = mailbox.hasRole()
          ? newDefaultTree
          : (mailbox.isPersonal ? newPersonalTree : newTeamMailboxTree);
        targetTree.root.addChildNode(currentNode);

        sortByMailboxNameNodeChildren(targetTree.root);
      }

      newAllMailboxes.add(currentNode.item);
    }

    // Commented out to prevent overriding custom sorting logic
    // sortNodeChildren(newDefaultTree.root);

    return (
      allMailboxes: newAllMailboxes,
      defaultTree: newDefaultTree,
      personalTree: newPersonalTree,
      teamMailboxTree: newTeamMailboxTree,
    );
  }

  Future<({
    MailboxTree defaultTree,
    MailboxTree personalTree,
    MailboxTree teamMailboxTree
  })> generateMailboxTreeInUIAfterRefreshChanges({
    required List<PresentationMailbox> allMailboxes,
    required MailboxTree currentDefaultTree,
    required MailboxTree currentPersonalTree,
    required MailboxTree currentTeamMailboxTree,
  }) async {
    final Map<MailboxId, MailboxNode> mailboxDictionary = HashMap();

    final newDefaultTree = MailboxTree(MailboxNode.root());
    final newPersonalTree = MailboxTree(MailboxNode.root());
    final newTeamMailboxTree = MailboxTree(MailboxNode.root());

    for (var mailbox in allMailboxes) {
      final currentMailboxNode = findExistingNode(
        id: mailbox.id,
        currentDefaultTree: currentDefaultTree,
        currentPersonalTree: currentPersonalTree,
        currentTeamMailboxTree: currentTeamMailboxTree,
      );

      // Override sortOrder for special mailboxes to ensure correct ordering
      final modifiedMailbox = _overrideSortOrderForSpecialMailboxes(mailbox);

      final newMailboxNode = MailboxNode(
        modifiedMailbox,
        expandMode: currentMailboxNode?.expandMode ?? ExpandMode.COLLAPSE,
        selectMode: currentMailboxNode?.selectMode ?? SelectMode.INACTIVE,
      );

      mailboxDictionary[mailbox.id] = newMailboxNode;
    }

    for (var mailbox in allMailboxes) {
      final currentNode = mailboxDictionary[mailbox.id];
      if (currentNode == null) continue;

      final parentId = mailbox.parentId;
      final parentNode = parentId != null ? mailboxDictionary[parentId] : null;

      if (parentNode != null) {
        parentNode.addChildNode(currentNode);
        sortByMailboxNameNodeChildren(parentNode);
      } else {
        final targetTree = mailbox.hasRole()
          ? newDefaultTree
          : (mailbox.isPersonal ? newPersonalTree : newTeamMailboxTree);
        targetTree.root.addChildNode(currentNode);

        sortByMailboxNameNodeChildren(targetTree.root);
      }
    }

    // Commented out to prevent overriding custom sorting logic
    // sortNodeChildren(newDefaultTree.root);

    return (
      defaultTree: newDefaultTree,
      personalTree: newPersonalTree,
      teamMailboxTree: newTeamMailboxTree,
    );
  }

  void sortNodeChildren(MailboxNode mailboxNode) {
    mailboxNode.childrenItems?.sort((a, b) => a.compareTo(b));
  }

  void sortByMailboxNameNodeChildren(MailboxNode mailboxNode) {
    mailboxNode.childrenItems?.sort((a, b) => a.compareTo(b));
  }

  MailboxNode? findExistingNode({
    required MailboxId id,
    required MailboxTree currentDefaultTree,
    required MailboxTree currentPersonalTree,
    required MailboxTree currentTeamMailboxTree,
  }) {
    return currentDefaultTree.findNode((node) => node.item.id == id) ??
      currentPersonalTree.findNode((node) => node.item.id == id) ??
      currentTeamMailboxTree.findNode((node) => node.item.id == id);
  }

  PresentationMailbox _overrideSortOrderForSpecialMailboxes(PresentationMailbox mailbox) {
    final name = mailbox.name?.name.toLowerCase() ?? '';
    final role = mailbox.role?.value.toLowerCase() ?? '';
    
    // Define custom sortOrder values for special mailboxes
    if (name == 'inbox' || role == 'inbox') {
      return mailbox.copyWith(sortOrder: SortOrder(sortValue: 1));
    } else if (name == 'sent' || role == 'sent') {
      return mailbox.copyWith(sortOrder: SortOrder(sortValue: 2));
    } else if (name == 'drafts' || role == 'drafts') {
      return mailbox.copyWith(sortOrder: SortOrder(sortValue: 3));
    } else if (name == 'trash' || role == 'trash') {
      return mailbox.copyWith(sortOrder: SortOrder(sortValue: 4));
    } else if (name == 'spam' || role == 'spam' || name == 'junk' || role == 'junk') {
      return mailbox.copyWith(sortOrder: SortOrder(sortValue: 5));
    }
    
    // Keep original sortOrder for other mailboxes
    return mailbox;
  }
}