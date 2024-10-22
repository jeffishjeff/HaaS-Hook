// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {IHooks} from "v4-core/interfaces/IHooks.sol";

library Subscriber {
    error CannotModifySubscriberZero();

    struct State {
        IHooks prev;
        IHooks next;
        uint32 gasRebateBps;
    }

    IHooks internal constant SUBSCRIBER_ZERO = IHooks(address(0));

    function updateGasRebate(mapping(IHooks => State) storage self, IHooks subscriber, uint32 gasRebateBps) internal {
        require(subscriber != SUBSCRIBER_ZERO, CannotModifySubscriberZero());

        if (self[subscriber].gasRebateBps == gasRebateBps) return;

        if (self[subscriber].gasRebateBps > 0) {
            self[self[subscriber].prev].next = self[subscriber].next;
            self[self[subscriber].next].prev = self[subscriber].prev;
            delete self[subscriber];
        }

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
