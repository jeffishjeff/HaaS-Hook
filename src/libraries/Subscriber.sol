// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {IHooks} from "v4-core/interfaces/IHooks.sol";

/// @notice Library for managing subscribers
library Subscriber {
    /// @notice Thrown when attempting to modify the subscriber origin
    error CannotModifySubscriberOrigin();

    /// @notice Struct for the state of a subscriber
    struct State {
        // previous subscriber in the linked list, sorted by gas rebate descending
        IHooks prev;
        // next subscriber in the linked list, sorted by gas rebate descending
        IHooks next;
        // gas rebate in basis points (relative to gas consumed) offered by the current subscriber
        uint32 gasRebateBps;
    }

    /// @notice The subscriber origin
    IHooks internal constant SUBSCRIBER_ORIGIN = IHooks(address(0));

    /// @notice Updates the gas rebate of a subscriber, sorted by gas rebate descending in the linked list
    /// @param self The linked list of subscribers
    /// @param subscriber The subscriber to update
    /// @param gasRebateBps The new gas rebate the subscriber is offering, in basis points
    function updateGasRebate(mapping(IHooks => State) storage self, IHooks subscriber, uint32 gasRebateBps) internal {
        // ensures that the subscriber is not the subscriber origin
        require(subscriber != SUBSCRIBER_ORIGIN, CannotModifySubscriberOrigin());

        // short-circuit if the gas rebate is unchanged
        if (self[subscriber].gasRebateBps == gasRebateBps) return;

        // if already exists (gas rebate is positive), remove the subscriber from the linked list
        if (self[subscriber].gasRebateBps > 0) {
            self[self[subscriber].prev].next = self[subscriber].next;
            self[self[subscriber].next].prev = self[subscriber].prev;
            delete self[subscriber];
        }

        // if new gas rebate is positive, insert the subscriber into the linked list
        if (gasRebateBps > 0) {
            IHooks current = self[SUBSCRIBER_ORIGIN].next;

            // keep looping until the end of the linked list or reach a subscriber with a lower gas rebate
            while (current != SUBSCRIBER_ORIGIN && self[current].gasRebateBps >= gasRebateBps) {
                current = self[current].next;
            }

            // insert the subscriber before the current subscriber
            self[subscriber] = State({prev: self[current].prev, next: current, gasRebateBps: gasRebateBps});
            self[self[subscriber].prev].next = subscriber;
            self[self[subscriber].next].prev = subscriber;
        }
    }
}
