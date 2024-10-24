// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {IHooks} from "v4-core/interfaces/IHooks.sol";

/// @notice Library for managing subscribers
library Subscriber {
    /// @notice Thrown when attempting to modify the subscriber zero
    error CannotModifySubscriberZero();

    // State of a subscriber
    struct State {
        // Previous subscriber in the linked list, sorted by gas rebate descending
        IHooks prev;
        // Next subscriber in the linked list, sorted by gas rebate descending
        IHooks next;
        // Gas rebate the current subscriber is paying, in basis points
        uint32 gasRebateBps;
    }

    // Subscriber zero
    IHooks internal constant SUBSCRIBER_ZERO = IHooks(address(0));

    /// @notice Updates the gas rebate of a subscriber in a linked list, sorted by gas rebate descending
    /// @param self The linked list of subscribers
    /// @param subscriber The subscriber to update
    /// @param gasRebateBps The new gas rebate of the subscriber, in basis points
    function updateGasRebate(mapping(IHooks => State) storage self, IHooks subscriber, uint32 gasRebateBps) internal {
        // Ensure that the subscriber is not the subscriber zero
        require(subscriber != SUBSCRIBER_ZERO, CannotModifySubscriberZero());

        // Short-circuit if the gas rebate is unchanged
        if (self[subscriber].gasRebateBps == gasRebateBps) return;

        // If already exists (gas rebate is positive), remove the subscriber from the linked
        if (self[subscriber].gasRebateBps > 0) {
            self[self[subscriber].prev].next = self[subscriber].next;
            self[self[subscriber].next].prev = self[subscriber].prev;
            delete self[subscriber];
        }

        // If new gas rebate is positive, insert the subscriber into the linked list
        if (gasRebateBps > 0) {
            IHooks current = self[SUBSCRIBER_ZERO].next;

            while (current != SUBSCRIBER_ZERO && self[current].gasRebateBps >= gasRebateBps) {
                current = self[current].next;
            }

            self[subscriber] = State({prev: self[current].prev, next: current, gasRebateBps: gasRebateBps});
            self[self[current].prev].next = subscriber;
            self[current].prev = subscriber;
        }
    }
}
