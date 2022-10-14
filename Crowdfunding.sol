// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0 <0.9.0;

/*
    A crowd-funding contract which allows users to create a campaign with a monetary goal and deadline. 
    Contributors are able to contribute to the crowd-fund by sending Ethereum, 
    and if the goal isn’t met by the deadline, contributors can request a refund. 

    If the goal is met however, the campaign owner (or admin) will be able to 
    spend the funds raised from the campaign. To spend this money, the admin must create a Spending Request, 
    which requires >50% of contributors to vote on it before the request is granted permission. 

    Once permission is granted from the voters, the admin can execute the Spending Request.
*/


contract CrowdFunding {
    /* Basic contract variables */
    mapping(address => uint256) public contributors;

    address public admin;
    uint256 public numContributors;
    uint256 public minContribution;
    uint256 public deadline;
    uint256 public goal;
    uint256 public raisedAmount;
    
    /* Spending Request variables */
    struct Request {
        string description;
        address payable recipient;
        uint value;
        bool completed;
        uint numVoters;
        mapping(address => bool) voters;
    }

    mapping(uint => Request) public requests;

    uint public numRequests;

    /* Goal amount in wei, deadline in seconds */
    constructor(uint256 _goal, uint256 _deadline) {
        goal = _goal;
        deadline = block.timestamp + _deadline; // in seconds
        minContribution = 100 wei;
        admin = msg.sender;
    }

    /* Events for JS implementation */
    event ContributeEvent(address _sender, uint _value);
    event CreateRequestEvent(string _description, address _recipient, uint _value);
    event MakePaymentEvent(address _recipient, uint _value);

    /*
    * Allows for contributions to the crowdfund as long as 
    * the deadline hasn't passed and the contribution is more 
    * than 100 wei.
    */
    function contribute() public payable {
        require(block.timestamp < deadline, "Deadline has passed :(");
        require(
            msg.value >= minContribution,
            "Minimum contribution not met! :("
        );

        if (contributors[msg.sender] == 0) {
            numContributors++;
        }

        contributors[msg.sender] += msg.value;
        raisedAmount += msg.value;

        emit ContributeEvent(msg.sender, msg.value);
    }

    receive() external payable {
        contribute();
    }

    /*
    *  Retrieve the balance of the deployed contract
    */
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /*
    * If the deadline has passed and the goal wasn't met, then 
    * contributors are able to request a refund
    */
    function getRefund() public {
        require(block.timestamp > deadline && raisedAmount < goal);
        require(contributors[msg.sender] > 0);

        address payable recipient = payable(msg.sender);
        uint value = contributors[msg.sender];
        recipient.transfer(value);

        contributors[msg.sender] = 0;
    }

    /*
    * Modifier to check whether the account calling createRequest/makePayment is an
    * admin.
    */
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function!");
        _;
    }

    /*
    * Admins of the crowdfund need to create Spending Requests in order to spend
    * money for the campaign. Contributors can then vote on that Spending Request.
    * If over 50% contributors vote, the money is granted.
    */
    function createRequest(string memory _description, address payable _recipient, uint _value) public onlyAdmin {
        Request storage newRequest = requests[numRequests];
        numRequests+=1;

        newRequest.description = _description;
        newRequest.recipient = _recipient;
        newRequest.value = _value;
        newRequest.completed = false;
        newRequest.numVoters = 0;

        emit CreateRequestEvent(_description, _recipient, _value);
    }

    /*
    * Voters can vote on a request (_requestNum is the index for requests mapping/array).
    */
    function voteRequest(uint _requestNum) public {
        require(contributors[msg.sender] > 0, "You must be a contributor to vote!");

        Request storage thisRequest = requests[_requestNum];

        require(thisRequest.voters[msg.sender] == false, "You have already voted!");
        
        thisRequest.voters[msg.sender] = true;
        thisRequest.numVoters+=1;
    }

    /*
    * If more than 50% of contributors have voted, then the Spending Request is granted
    * and admins will be able to make the payment to the Spend Request recipient.
    */
    function makePayment(uint _requestNum) public onlyAdmin {
        require(raisedAmount >= goal);
        Request storage thisRequest = requests[_requestNum];
        require(thisRequest.completed == false, "The request was already completed!");
        require(thisRequest.numVoters > numContributors / 2, "Not enough contributors voted.");

        thisRequest.recipient.transfer(thisRequest.value);
        thisRequest.completed = true;

        emit MakePaymentEvent(thisRequest.recipient, thisRequest.value);
    }
}
