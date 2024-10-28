// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

/// @notice Library for global or pool specific identifiers
library GlobalOrPoolId {
    /// @notice The global identifier
    PoolId internal constant GLOBAL_ID = PoolId.wrap(0);

    /// @notice Converts a pool key to its respective global or pool specific identifier
    /// @param poolKey The pool key to convert
    /// @return The global or pool specific identifier
    function toGlobalOrPoolId(PoolKey memory poolKey) internal pure returns (PoolId) {
        return poolKey.currency0 == CurrencyLibrary.ADDRESS_ZERO && poolKey.currency1 == CurrencyLibrary.ADDRESS_ZERO
            ? GLOBAL_ID
            : poolKey.toId();
    }
}
