pragma solidity ^0.4.24;

// import "./ERC721.sol";

import "./Universe.sol";

contract Event /* is ERC721 */  {
    
  struct TicketInfo {
    uint256 d_prev_price;
    bool    d_used;
  }
 
  string public description;
 
  uint256 internal d_creator_commission_factor = 100; /* 1% commission */
 
  address internal d_admin;
  address internal d_organizer;
  
  
  // Array with all token ids, used for enumeration
  TicketInfo[] internal d_tickets;
  
  // Mapping from owner to list of owned token IDs
  mapping(address => uint256[]) internal d_owner_tokens;
  
  // Mapping from token id to owner address
  mapping(uint256 => address) internal d_token_owner;
  
  // For transfers 
  mapping(uint256 => uint256) internal d_token_ask;

  constructor(string _description, address _organizer) public { 
    description = _description;
    d_admin = msg.sender;
    d_organizer = _organizer;
  }
  
  function issue(uint256 _numTickets,uint256 _price) public {
    require(msg.sender == d_organizer);
    // require(_price > d_creator_commission_factor * 1 szabo,
    //         "Minimum cost is 100 szabo"); // Denominate in szabo
    
    for(uint256 i=0;i<_numTickets;++i) {
      d_tickets.push(TicketInfo({d_prev_price:_price,d_used:false}));
    }
  }

  function getCostFor(uint256 _numTickets) public constant returns(uint256) {
    uint256 total_cost=0;
    uint256 bought=0;
    
    // We will buy 1 ticket at a time
    // If while buying, we do not find enough tickets, 
    // or we did not get enough money, we throw
    for(uint256 i=0;i<d_tickets.length && bought < _numTickets;++i) {
      if (d_token_owner[i] != address(0)) { continue; }
        
      // Ticket can be bought 
      total_cost+=d_tickets[i].d_prev_price;
      bought++;
    }
    
    require(bought == _numTickets, "Not enough tickets!");

    return total_cost;
  }
  
  function buy(uint256 _numTickets) public payable {
    uint256 total_cost=0;
    uint256 bought=0;
    
    // We will buy 1 ticket at a time
    // If while buying, we do not find enough tickets, 
    // or we did not get enough money, we throw
    for(uint256 i=0;i<d_tickets.length && bought < _numTickets;++i) {
      if (d_token_owner[i] != address(0)) { continue; }
        
      // Ticket can be bought 
      total_cost+=d_tickets[i].d_prev_price;
      d_owner_tokens[msg.sender].push(i);
      d_token_owner[i] = msg.sender;
      bought++;
  
    }
    
    require(bought == _numTickets, "Not enough tickets!");
    require(total_cost <= msg.value, "Cost is more than transaction value.");
    
    // Take admin cut
    uint256 commission = msg.value / d_creator_commission_factor;
    address(d_admin).transfer(commission);
    
    Universe u = Universe(d_admin);
    u.addUserEvent(msg.sender,this);
  }
  
  function getBalance() public constant returns(uint) {
    require(msg.sender == d_admin || msg.sender == d_organizer);
    return address(this).balance;
  }
  
  function withdraw() public {
    require(msg.sender == d_organizer);
    address(d_organizer).transfer(getBalance());
  }
  
  function numSold() public constant returns(uint256) {
    uint256 numSoldCount=0;
    for(uint256 i=0;i<d_tickets.length;++i) {
      if (d_token_owner[i] != address(0)) { numSoldCount++;}
    }
    return numSoldCount;
  }
  
  function numUnSold() public constant returns(uint256) {
    uint256 numUnSoldCount=0;
    for(uint256 i=0;i<d_tickets.length;++i) {
      if (d_token_owner[i] == address(0)) { numUnSoldCount++; }
    }
    return numUnSoldCount;
  }

  function numUsed() public constant returns(uint256) {
    uint256 numUsedCount=0;
    for(uint256 i=0;i<d_tickets.length;++i) {
      if (d_tickets[i].d_used) { numUsedCount++; } 
    }
    return numUsedCount;
  }

  function numToBeUsed() public constant returns(uint256) {
    uint256 numToBeUsedCount=0;
    for(uint256 i=0;i<d_tickets.length;++i) {
      if (!d_tickets[i].d_used && d_token_owner[i] != address(0)) { numToBeUsedCount++; } 
    }
    return numToBeUsedCount;
  }
  
  function balanceOf(address _owner) public constant returns (uint256 _balance) {
    return d_owner_tokens[_owner].length;    
  }
  
  function ownerOf(uint256 _tokenId) public constant returns (address _owner) {
    return d_token_owner[_tokenId];    
  }
  
  function exists(uint256 _tokenId) public constant returns (bool _exists) {
    return _tokenId >= 0 && _tokenId < d_tickets.length;
  }
  
  function myTickets() public constant returns(uint256[]) {
    return d_owner_tokens[msg.sender];
  }
  
  function proposeSale(uint256 _token,uint256 _price) public {
    require(d_tickets[_token].d_used == false, "Ticket already used!");
    require(d_token_owner[_token] == msg.sender);
    d_token_ask[_token] = _price;
  }
  
  function retractSale(uint256 _token) public {
    require(d_token_owner[_token] == msg.sender);
    delete d_token_ask[_token];
  }
  
  function hitAsk(uint256 _token) public payable {
    require(!d_tickets[_token].d_used, "Ticket already used!");
    require(d_token_ask[_token] > 0 && msg.value > d_token_ask[_token]);
      
    // Value provided, okay to transfer
    delete d_token_ask[_token]; // No more ask 
    
    address prev_owner = d_token_owner[_token];
    
    uint256[] storage prev_owner_tokens = d_owner_tokens[prev_owner];
    for (uint256 i = 0;i<prev_owner_tokens.length; ++i) {
      if (prev_owner_tokens[i] == _token) {
        prev_owner_tokens[i] = prev_owner_tokens[prev_owner_tokens.length-1];
        delete prev_owner_tokens[prev_owner_tokens.length-1];
        prev_owner_tokens.length = prev_owner_tokens.length-1;
        break;
      }
    }
    
    d_token_owner[_token] = msg.sender;
    d_owner_tokens[msg.sender].push(_token);
    
    // Take money
    if (d_tickets[_token].d_prev_price > msg.value) {
      // Selling for less, all money to seller 
      address(prev_owner).transfer(msg.value);
    } else {
      uint256 premium = msg.value - d_tickets[_token].d_prev_price;
      uint256 seller_premium = premium / 2;
      
      // TODO Review
      address(prev_owner).transfer(seller_premium + d_tickets[_token].d_prev_price);
      
      // Other half premium is for the event, and commission out of it 
      uint256 commission = seller_premium / d_creator_commission_factor;
      address(d_admin).transfer(commission);
      
      d_tickets[_token].d_prev_price = msg.value;
    }
  }
  
  function ticketUsed(uint256 _tokenId) public constant returns(bool) {
      return d_tickets[_tokenId].d_used;
  }

  // https://medium.com/@libertylocked/ec-signatures-and-recovery-in-ethereum-smart-contracts-560b6dd8876
  function ticketVerificationCode(uint256 _tokenId) public constant returns(bytes32) {
    require(!ticketUsed(_tokenId), "Ticket already used!");
    return keccak256(abi.encodePacked(_tokenId,address(this)));
  }
  
  function isOwnerSig(uint256 _tokenId, bytes memory signature) public constant returns(bool) {
    return d_token_owner[_tokenId] == 
            recover(ticketVerificationCode(_tokenId),signature);
  }

  function useTicket(uint256 _tokenId, bytes memory signature) public returns(bool) {
    require(isOwnerSig(_tokenId,signature), "Incorrect usage signature!");
    require(!ticketUsed(_tokenId), "Ticket already used!");
    d_tickets[_tokenId].d_used = true;
    delete d_token_ask[_tokenId]; // Just in case
    return true;
  }

/* TODO Cannot use since we cannot pass in bytes[] as an argument
  function useTickets(uint256[10] _tokenIds, bytes signatures) public returns(bool) {
    require(_tokenIds.length == signatures.length);
    for(uint256 i=0;i<_tokenIds.length && i < signatures.length; ++i) {
      useTicket(_tokenIds[i],signatures[i]);
    }
    return true;
  }
*/

  function recover(bytes32 message, bytes memory signature) internal pure returns (address) {
      (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);
      return ecrecover(message,v, r, s);
  }
  
  function splitSignature(bytes memory sig) internal pure returns (uint8 v, bytes32 r, bytes32 s)
  {
    require(sig.length == 65);
    assembly {
      // first 32 bytes, after the length prefix
      r := mload(add(sig, 32))
      // second 32 bytes
      s := mload(add(sig, 64))
      // final byte (first byte of the next 32 bytes)
      v := byte(0, mload(add(sig, 96)))
    }
    return (v, r, s);
  }


/*
  function approve(address _to, uint256 _tokenId) public;
  function getApproved(uint256 _tokenId) public constant returns (address _operator);

  function setApprovalForAll(address _operator, bool _approved) public;
  function isApprovedForAll(address _owner, address _operator) public constant returns (bool);

  function transferFrom(address _from, address _to, uint256 _tokenId) public;
  function safeTransferFrom(address _from, address _to, uint256 _tokenId) public;
*/
}
