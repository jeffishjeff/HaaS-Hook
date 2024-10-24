// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

/// @notice Library for PoolKey functions
library PoolKeyLibrary {
    /// @notice Returns the pool ID, or the zero ID if pool key's currency pair is empty
    function toIdOrZero(PoolKey memory poolKey) internal pure returns (PoolId) {
        return poolKey.currency0 == CurrencyLibrary.ADDRESS_ZERO && poolKey.currency1 == CurrencyLibrary.ADDRESS_ZERO
            ? PoolId.wrap(0)
            : poolKey.toId();
    }
}
