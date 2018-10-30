pragma solidity ^0.4.24;

import "./Event.sol";

contract Universe {
  
  address private d_owner;
  
  event OrganizerEvents(
        address indexed eventAddr,
        address indexed organizerAddr,
        bool    indexed active,
        string          description
  );
        
  event UserEvents(
        address indexed eventAddr,
        address indexed userAddr,
        bool    indexed active);
  
  constructor() public payable {
    d_owner = msg.sender;
  }
  
  function() public payable {}
  
  function getBalance() public constant returns(uint) {
    return address(this).balance;
  }

  function isOwner() public constant returns(bool) {
    return msg.sender == d_owner;
  }
  
  function withdraw() public {
    require(msg.sender == d_owner);
    address(d_owner).transfer(getBalance());
  }
  
  function createEvent(string _description) public payable returns(address) {
    address eventAddr = new Event(_description,msg.sender);
    emit OrganizerEvents(eventAddr, msg.sender, true,_description);
    return eventAddr;
  }
  
  function addUserEvent(address _user,address _event) public {
      emit UserEvents(_event,_user,true);
  }
  
  function removeUserEvent(address _user,address _event) public {
      emit UserEvents(_event,_user,false);
  }
  
}
