//Write your own contracts here. Currently compiles using solc v0.4.15+commit.bbb8e64f.
pragma solidity ^0.4.24;
import "github.com/SecurityTokenStandard/EIP-Spec/blob/19c41c54913d87dca3086ba68121d5e883184fe4/contracts/ERC1644/IERC1644.sol";
import "github.com/provable-things/ethereum-api/provableAPI_0.4.25.sol";



contract clauseExclusion is usingProvable, IERC1644  {

    event statutRequete(string description);

    address adresseAssocie;
    uint256 totalActionsAssocie; 
    bytes informationsExclusion; 
    bytes informationsSociete;
    
    IERC1644 public tokenAction; // ERC20 being used as the underlying asset




   function requeteProcedureColl() payable {
       if (provable_getPrice("URL") > this.balance) {
           emit statutRequete("La requete ne peut pas etre envoye car pas assez de ether");
       } else {
           emit statutRequete("La requete a pu etre envoye, en attente d une reponse...");
           provable_query("URL", "json(https://api.datainfogreffe.fr/api/v1/Entreprise/ProceduresCollectives/{numeroSiren}?{tokenId}).ExistenceProcedure");
       }
   }



  function __callback(
        bytes32 _myid,
        string result
    )
        public
    {
        require(msg.sender == provable_cbAddress());

      if (keccak256 (bytes(result)) == keccak256 ("OUI") )

 {
        tokenAction.controllerTransfer(adresseAssocie, this, totalActionsAssocie, informationsExclusion, informationsSociete);
        emit ControllerTransfer(this, adresseAssocie,this,totalActionsAssocie,informationsExclusion, informationsSociete);
    }
    }








}
