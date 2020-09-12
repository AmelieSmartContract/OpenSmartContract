

pragma solidity ^0.5.0;


    /**
	 * peu importe le standard de token utilisé pour représenter les titres ou les stablecoins,
	 * il suffit qu'il mette en place au minimum les fonctions de l'ERC20 ci dessous.
	 */


interface IERC20 {
   
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);
 
    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}




contract contratOption {

//on instancie les différents états du contrat

	enum ETATCONTRAT {
		none,
		initialise, 
		ouvert, 
		exerce, 
		ferme 
	}

    ETATCONTRAT public etatsContrat;

	// Evenements qui se déclenchent aux différentes étapes du contrat
	event Initialise (address indexed _vendeur, uint256 _montantAction);
	event Ouvert(address indexed _acheteur, uint256 _prixDOption);
	event Exerce(address indexed _acheteur, uint256 _prixDExercice);
	event Ferme(address indexed _seller);

	address public acheteur;
	address public vendeur;

	IERC20 public tokenAction; // token qui représente l'action
	IERC20 public tokenPaiement; // token qui représente le stablecoin

	uint256 public nbActions; // nombre d'actions 
	uint256 public prixAction; 
	uint256 public prixOption; // prix a payé par l'acheteur pour le droit d'option
	uint256 public dateExpiration; // date en unix après laquelle l'acheteur ne peut plus exercer droit d'option
	uint256 public prixExercice;

	/**
	 * Le vendeur initie le contrat en paramétrant toutes les variables.
	 * The Seller should also have already "allowed" the ERC20 to be transferred in by the contract
	 * in the amount specified by premiumAmount.  This will be held in escrow.
	 */
	 
	constructor(
		IERC20 _tokenAction,
		uint256 _nbActions,
		IERC20 _tokenPaiement,
		uint256 _prixExercice,
		uint256 _prixOption,
		uint _dateExpiration
	) public {
	    
		require(address(_tokenAction) != address(0));
		require(_nbActions > 0);
		require(address(_tokenPaiement) != address(0));
		require(_prixExercice > 0);
		require(_prixOption > 0);
		require(_dateExpiration > now);

		// Save off the inputs
		vendeur = msg.sender;
		tokenAction = _tokenAction;
		nbActions = _nbActions;
		tokenPaiement = _tokenPaiement;
		prixExercice = _prixExercice;
		prixOption = _prixOption;
		dateExpiration = _dateExpiration;

		// l'etat du contrat est sur none
		etatsContrat = ETATCONTRAT.none;
	}

	function initialize() public {
		require(
			etatsContrat == ETATCONTRAT.none
		);

		require(msg.sender == vendeur, "Seul le vendeur peut initialiser le contrat");

		// Les actions sont envoyées en séquestre
		require(tokenAction.transferFrom(vendeur, address(this), nbActions), "Doit envoyer les actions en séquestre");

		// met à jour l'etat du contrat
		etatsContrat = ETATCONTRAT.initialise;

		// Emet l'evenement
		emit Initialise(vendeur, nbActions);
	}



	/**
	 * Une fois le contrat ouvert par le vendeur, l'acheteur peut.....
	 */
	 
	function open() public {
		// Validate contract state
		require(now < dateExpiration);
		
		require(etatsContrat == ETATCONTRAT.initialise);

		// Save off the buyer
		acheteur = msg.sender;

		// Transfer the tokens over to the seller
		require(tokenPaiement.transferFrom(acheteur, vendeur, prixOption));

		// Set the status to open
		etatsContrat = ETATCONTRAT.ouvert;

		// Emit the event
		emit Ouvert(acheteur, prixOption);
	}

	/**
	 * If the contract was never opened by a buyer or the contract was never redeemed and it expired,
	 * the seller can close it out and get back the initial underlying asset token.
	 */

	/**
	 * After a buyer has opened the contract they can redeem their right to the underlying asset.
	 * They can only do this if the contract is in the open state and it has not expired.
	 * They must pay the purchase price times the asset amount and they will get the underlying asset in return.
	 * The buyer must have already "allowed" the contract to transfer the payment amount of purchasingTokens
	 */
	 
	function redeem() public {
		// Validate contract state
		require(etatsContrat == ETATCONTRAT.ouvert && now < dateExpiration);
		require(msg.sender == acheteur);

		// Calculate the amount of tokens that should be paid
		uint256 montantPaiement = nbActions * prixExercice;

		// Move the payment from the buyer to the seller
		require(tokenPaiement.transferFrom(acheteur, vendeur, montantPaiement));

		// Pay out the buyer from escrow
		tokenAction.transfer(acheteur, nbActions);

		// Set the status to closed
		etatsContrat = ETATCONTRAT.ferme;

		// Emit the event
		emit Ferme(acheteur, montantPaiement);
	}

}
