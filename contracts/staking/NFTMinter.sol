pragma solidity ^0.8.5;

import "../tokens/Cane.sol";

 abstract contract NFTMinter is Cane {

	function produce(address to) internal {
		mint(tx.origin);
	}
}