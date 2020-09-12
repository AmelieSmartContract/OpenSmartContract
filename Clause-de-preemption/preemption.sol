pragma solidity ^0.5.0;

interface IERC20 {
   
    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);
   
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    
    function totalSupply() external  view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);

}



contract clausePreemption is IERC20 {
    
    enum EtatsContrat {
		none, //
		initialise, // 
		ouvertAPreemption, // 
		pretarepartir,
		preemptionTerminee // 
		}
	
	EtatsContrat public etatContrat;
    
    
    struct Associe {
        uint256 prixAPayer;
        uint256 actionsSouhaitees;
        bool droitExerce;
        bool droitEpuise;
    }
    
    mapping (address => Associe) public associesPreemptaires;
    mapping (address => uint256 ) cedants; //

    address cessionnaire;
    address cedant;

    IERC20 public tokenAction;      
    IERC20 public tokenAchat;     
    
    uint256 public nbActionsAVendre; 
    uint256 public nbActionsVoulues;
    uint256 public prixAction;    
    uint256 public delai;        
    uint256 public prixCession; 
    uint256 public nbActionsPreemptees; 
    
    
    
    event ouvertAPreemption(uint prixAction, uint nbreActions);
    event EchecPreemption(uint quantiteToken, uint nbreActionsPreemptes);
    event ReussitePreemption(uint quantiteToken);
    
    
        // constructor qui set l'etat et les token

    
    function transfertAction(uint256 _nbActionsAVendre, uint256 _prixAction, address _cessionnaire) public { //** utiliser la convention
        
        require (etatContrat == EtatsContrat.none);
        require (tokenAction.balanceOf(msg.sender) > 0); //** check si est un actionnaire
        require (_nbActionsAVendre <= tokenAction.balanceOf(msg.sender)); //** regarde si il assez de tokenAction
        
        
        cedant = msg.sender;//** cedant est le msg.sender
        nbActionsAVendre = _nbActionsAVendre; // on met à jour la quantité d'action à vendre
        prixAction = _prixAction;             // on met à jour le prix de l'action
        prixCession = nbActionsAVendre * prixAction;  // on calcule le prix à payer


        if (tokenAction.balanceOf(cessionnaire) == 0){ //cessionnaire =/= associé
            
            cedants [cedant] += nbActionsAVendre;
            
            require(tokenAction.transferFrom(cedant, address(this), nbActionsAVendre));
            
            delai = now;
            
            etatContrat = EtatsContrat.ouvertAPreemption;

        }
        
        else { 
            
            // a determiner
            
            }
    }
    
    
    
    
    
    function exercicePreemption(uint _nbActionsVoulues) public {
        
        require(etatContrat == EtatsContrat.ouvertAPreemption);
        
        require(now < delai + 91 days);
        
        require (msg.sender != cedant);
        
        require(tokenAction.balanceOf(msg.sender) > 0);
        
        Associe storage exerceur = associesPreemptaires[msg.sender];

        require(exerceur.droitExerce == false);   // require qu'il n'a pas déjà exercé son droit de préemption
        
        require(_nbActionsVoulues <= nbActionsAVendre);
        
        exerceur.droitExerce = true;

        exerceur.actionsSouhaitees = _nbActionsVoulues;
        
        exerceur.prixAPayer = _nbActionsVoulues * prixAction;
        
        nbActionsPreemptees += _nbActionsVoulues;
        
        require(tokenAchat.transferFrom(msg.sender, address(this), exerceur.prixAPayer));
    
        etatContrat = EtatsContrat.pretarepartir; 

    }
	
    
    
    function repartitionPreemption() public {
        
        
        require(etatContrat == EtatsContrat.pretarepartir);
        
        require(now > delai + 91 days);
        
        require(associesPreemptaires[msg.sender].droitExerce == true);
        
        require(associesPreemptaires[msg.sender].droitEpuise == false);

        
        associesPreemptaires[msg.sender].droitEpuise = true;

        
        Associe storage preemptaire  =  associesPreemptaires[msg.sender];
        
        
        
        if(nbActionsAVendre > nbActionsPreemptees) { // si le nombre d'actions préemptées est inférieur au nombre d'actions à vendre
            
            uint256 montant = preemptaire.prixAPayer;
        
            require(tokenAchat.transfer(msg.sender, montant));
            
            // a determiner : le transfert vers le cessionnaire peut se faire ici 
            etatContrat = EtatsContrat.preemptionTerminee; 


            
        }
        
        else if (nbActionsAVendre == nbActionsPreemptees) {
            
            uint256 quantiteActions =  preemptaire.actionsSouhaitees;
            uint256 prixVente = preemptaire.prixAPayer;
            require(tokenAction.transfer(msg.sender, quantiteActions));
            require(tokenAchat.transfer(cedant, prixVente ));
            
            
            
        } else  {    // si nbActionsAVendre < nbActionsPreemptes
            
                
                uint256 totalActions = tokenAction.totalSupply();
                
                uint256 partAssocie = ((tokenAction.balanceOf(msg.sender)) / totalActions) * 100;
                
                uint256 actionsProrata = (nbActionsAVendre * partAssocie) /100;
                
                uint256 actionsAEnvoyer;
                

                if (actionsProrata > preemptaire.actionsSouhaitees ) {
                    
                    actionsAEnvoyer = preemptaire.actionsSouhaitees;
                     
                }  else {
                   
                     actionsAEnvoyer  = actionsProrata;
                }
                
                // on transfère le nombre d'actions à l'associé
                require(tokenAction.transfer(msg.sender, actionsAEnvoyer));
                

        }
    }
    
}
