/**
 *Submitted for verification at Etherscan.io on 2019-07-28
*/

// poole_party
// File: openzeppelin-solidity/contracts/token/ERC20/IERC20.sol

pragma solidity ^0.5.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see `ERC20Detailed`.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through `transferFrom`. This is
     * zero by default.
     *
     * This value changes when `approve` or `transferFrom` are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * > Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an `Approval` event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to `approve`. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// File: contracts/CoveredCall.sol

pragma solidity 0.5.8;


contract contratATerme {

	// Enum of the different states the contract can be in
	enum ContractStates {
		NONE,
		STATUS_INITIALIZED, 
		STATUS_OPEN, 
		STATUS_REDEEMED 
	}

	// The current state of the contract as it flows through different actions.
	ContractStates public currentState;

	// Events triggered when users take action
	event Opened(address indexed _buyer);
	event Redeemed(address indexed _buyer);

	address public buyer; // The address that created the contract
	address public seller; // The address that purchased the option

	IERC20 public underlyingAssetToken; // ERC20 being used as the underlying asset
	IERC20 public purchasingToken; // ERC20 being used for premium and redeem payments

	uint256 public underlyingAssetAmount; // Amount of the underlying asset being offered in the contract

	uint256 public assetPrice; // This is the strike price required to redeem. Redeem amount = strike * asset amount.

	uint256 public expirationDate; 

	/**
	 * The Seller initiates the contract by setting all parameters.
	 * The Seller should also have already "allowed" the ERC20 to be transferred in by the contract
	 * in the amount specified by premiumAmount.  This will be held in escrow.
	 */
	constructor(
		IERC20 _underlyingAssetToken,
		uint256 _underlyingAssetAmount,
		IERC20 _purchasingToken,
		uint256 _assetPrice,
		uint _expirationDate
	) public {
		// Validate inputs
		require(address(_underlyingAssetToken) != address(0), "The asset token must not be 0x0");
		require(_underlyingAssetAmount > 0, "The asset amount must be valid");
		require(address(_purchasingToken) != address(0), "The purchasing token must not be 0x0");
		require(_assetPrice > 0, "The strike price must be valid");
		require(_expirationDate > now, "The expiration must be in the future");

		// Save off the inputs
		seller = msg.sender;
		underlyingAssetToken = _underlyingAssetToken;
		underlyingAssetAmount = _underlyingAssetAmount;
		purchasingToken = _purchasingToken;
		assetPrice = _assetPrice;
		expirationDate = _expirationDate;

		// Make the contract be in a dead state
		currentState = ContractStates.NONE;
	}

	function initialize() public {
		require(
			currentState == ContractStates.NONE,
			"Contract must be in NONE state to allow initialization"
		);

		require(msg.sender == seller, "Only the original seller can initialize the contract");

		// Transfer in the underlying asset to escrow
		require(underlyingAssetToken.transferFrom(seller, address(this), underlyingAssetAmount), "Must provide initial escrow token");

		// Update the state to initialized
		currentState = ContractStates.STATUS_INITIALIZED;

		// Emit the event
		emit Initialized(seller, underlyingAssetAmount);
	}

	/**
	 * When the contract is in an initialized state, the seller can updated the premium amount to reflect real world price changes.
	 */

	/**
	 * The buyer can call this to open the contract.
	 * THe buyer must have already "allowed" the contract to transfer premiumAmount purchasingTokens
	 */
	function payForward() public {
		// Validate contract state
		require(now < expirationDate, "Cannot open an expired contract");
		require(currentState == ContractStates.STATUS_INITIALIZED, "Contract must be in initialized state to open");
		require(msg.sender == buyer, "Only the  buyer can pay the forward");

		// Save off the buyer
		buyer = msg.sender;

		require(purchasingToken.transferFrom(buyer, address(this), underlyingAssetAmount), "Must provide initial escrow token");

		// Set the status to open
		currentState = ContractStates.STATUS_OPEN;

		// Emit the event
		emit Opened(buyer);
	}


	function withdraw() public {
		// Validate contract state
		require(currentState == ContractStates.STATUS_OPEN);
		require(msg.sender == buyer || msg.sender == seller);
    require(now > expirationDate,);


		// Pay out the buyer from escrow
		underlyingAssetToken.transfer(buyer, underlyingAssetAmount);

    purchasingToken.transfer(seller, assetPrice);

		// Set the status to closed
		currentState = ContractStates.STATUS_REDEEMED;

		// Emit the event
		emit Redeemed(buyer);
	}




}
