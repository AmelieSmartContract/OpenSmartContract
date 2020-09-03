pragma solidity ^0.5.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/SafeMath.sol";

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see `ERC20Detailed`.
 */
interface IERC20 {
    
    using SafeMath for uint256;

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


}


/// @title IERC1644 Controller Token Operation (part of the ERC1400 Security Token Standards)
/// @dev See https://github.com/SecurityTokenStandard/EIP-Spec

contract IERC1644 is IERC20 {

    // Controller Operation
    function controllerTransfer(address _from, address _to, uint256 _value, bytes calldata _data, bytes calldata  _operatorData) external;
   

    // Controller Events
    event ControllerTransfer(
        address _controller,
        address indexed _from,
        address indexed _to,
        uint256 _value,
        bytes _data,
        bytes _operatorData
    );

}


contract clauseBuyOrSell is IERC1644 {
    
    enum EtatsContrat {
		STATUS_INITIALIZED,
		STATUS_PROPOSITION_FAITE, 
		STATUS_PROPOSITION_TRAITEE
	}
	
    // Permet d'enregistrer le statut du contrat
	EtatsContrat public etatContrat;
    
    mapping(address => uint256) balances;
    
    struct Associe {
        address addr;   // l'adresse de l'associé
        bool aPropose;  // cette variable va nous permettre d'identifier quel associé a proposé une offre, cela évitera qu'un associé accepte une offre qu'il a lui même proposé
    }
    
    Associe[] public associes; // tableau de deux associés (l'index commence à 0)
    
    IERC1644 public tokenPaiement;
    IERC1644 public tokenAction;
    
    uint public delai;
    uint public prix;
    bytes data; 
    bytes operatorData;
    
    constructor(address _associeDesigne) public {
        
        require(address(_associeDesigne) != address(0), "L'adresse de l'associé ne doit pas être 0x0");
        
        // On crée les deux associés
        Associe memory associe = Associe(msg.sender, false);
        Associe memory associeDesigne = Associe(_associeDesigne, false);
        
        associes.push(associe);    // associes[0] == associe
        associes.push(associeDesigne);    // associes[1] == associeDesigne
        
        etatContrat = EtatsContrat.STATUS_INITIALIZED;
    }
    
    function proposition(uint _montant) public {
        
        require(msg.sender == associes[0].addr);
        require(associes[0].aPropose == false);
        require(etatContrat == EtatsContrat.STATUS_INITIALIZED);
        
        // On transfère les token des deux associés au smart contract
        tokenAction.transfer(address(this), _montant); 
        
        //on force le transfert des actions de l'associé désigné au smart contract
        tokenAction.controllerTransfer(associes[1].addr, address(this), _montant, data, operatorData);
        
        associes[0].aPropose = true;
        prix = _montant;
        delai = now;
        etatContrat = EtatsContrat.STATUS_PROPOSITION_FAITE;
            
    }
    
    function recupererAction() public {
        
        require(etatContrat == EtatsContrat.STATUS_PROPOSITION_FAITE);
        require(associes[0].aPropose == true);
        
        // si délai pas passé
        if(now < delai + 60 days) {
            // et si msg sender est l'associé désigné
            if(msg.sender == associes[1].addr) {
                //on vérifie que l'associé désigné a bien payé l'associé (associes[0].addr = l'adresse de l'associé)
                require(tokenPaiement.transfer(associes[0].addr, prix));
                tokenAction.controllerTransfer( associes[0].addr, associes[1].addr, prix, data, operatorData);
                
                etatContrat = EtatsContrat.STATUS_PROPOSITION_TRAITEE;
                //on réinitialise le boolean
                associes[0].aPropose = false;
            }
        } else if(now > delai+ 60 days) { // si délai passé
            if(msg.sender == associes[0].addr) { //si le msg sender est l'associé initiateur
                //on vérifie que l'associé initiateur a bien payé l'associé déésigné (asspcoes[1].addr = l'adresse de l'associé désigné)
                require(tokenPaiement.transfer(associes[1].addr, prix));
                tokenAction.controllerTransfer(associes[1].addr, associes[0].addr, prix, data, operatorData);
                
                etatContrat = EtatsContrat.STATUS_PROPOSITION_TRAITEE;
                //on réinitialise le boolean
                associes[0].aPropose = false;
            }
        }
    }
    
    
    
    //implémentation des fonctions liées aux tokens
    function balanceOf(address tokenOwner) public view returns (uint) {
        return balances[tokenOwner];
    }
    
    function transfer(address receiver, uint numTokens) public returns (bool) {
      require(numTokens <= balances[msg.sender]);
      balances[msg.sender] = balances[msg.sender] - numTokens;
      balances[receiver] = balances[receiver] + numTokens;
      emit Transfer(msg.sender, receiver, numTokens);
      return true;
    }
    
    function transferFrom(address owner, address buyer, uint numTokens) public returns (bool) {
      require(numTokens <= balances[owner]);
      balances[owner] = balances[owner] - numTokens;
      balances[buyer] = balances[buyer] + numTokens;
      emit Transfer(owner, buyer, numTokens);
      return true;
}

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        balances[sender] = balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        balances[recipient] = balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function controllerTransfer(address _from, address _to, uint256 _value, bytes calldata  _data, bytes calldata  _operatorData) external {
        _transfer(_from, _to, _value);
        emit ControllerTransfer(msg.sender, _from, _to, _value, _data, _operatorData);
    }
}