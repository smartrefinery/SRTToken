pragma solidity ^0.4.11;

import './token/BasicToken.sol';
import './token/ERC20.sol';
import './ownership/Ownable.sol';
import './lifecycle/MigrateAgent.sol';

contract SRTToken is ERC20, BasicToken, Ownable {

  mapping (address => mapping (address => uint256)) internal allowed;

  string public constant name = "SRTToken";
  string public constant symbol = "SRT";
  uint256 public constant MULTIPLIER = 10 ** uint256(decimals);
  uint256 public constant INITIAL_SUPPLY = 100000000 * MULTIPLIER;
  uint256 public constant TOKENS_FOR_SELLE = 62000000 * MULTIPLIER;
  uint8 public constant decimals = 5;
  uint8 public constant STAGE1 = 0; //PRE-ICO
  uint8 public constant STAGE2 = 1; //1 stage of ICO
  uint8 public constant STAGE3 = 2; //2 stage of ICO
  uint8 public constant STAGE4 = 3; //3 stage of ICO
  uint8 public constant STAGE5 = 4; //ICO is complete

  uint8 public stage = 0; //current stage of ICO
  uint256 public tokensSoldInCurrentStage = 0; //amount of tokens were sold in current stage
  uint256 public minTokensAmount = 0; //min amount of tokens investor can have
  uint256 public maxTokensAmount; //max amount of tokens investor can have
  uint256 public tokenPrice; //price per token in wei
  uint256 public buyDiscount = 15; //discount percents, investor receives amount + amount * buyDiscount
  uint256 public totalWithdrawalAmountInControl = 0; //total amount of withdrawals, used to control 10% per month
  uint256 public totalEarnedEthBalance; // total amount ETH contract received during ICO
  uint256 public timeCreated; //time when smart contract was deployed
  uint256 public requestedWithdrawal; //requested amount of ETH for withdrawal
  address public benefactor; //address where ETH will be delivered
  address public company; //address of company, for bonuses program
  address public consultants; //address of consultants, for bonuses program
  address public advisoryBoard; //address of advisory board, for bonuses program
  address public bounty; //address of bounty, for bonuses program
  address public infrostructure; //address of infrostructure, for bonuses program
  address public escrow1; //address which will be used to allow withdrawal
  address public escrow2; //address which will be used to allow withdrawal
  address public escrow3; //address which will be used to allow withdrawal
  address public migrationAgent; //contract address for migration
  bool public escrow1Accepted; //marker that escrow1 's accepted withdrawal reqest
  bool public escrow2Accepted; //marker that escrow2 's accepted withdrawal reqest
  bool public escrow3Accepted; //marker that escrow3 's accepted withdrawal reqest

  function SRTToken() {
    totalSupply = INITIAL_SUPPLY;
    balances[msg.sender] = INITIAL_SUPPLY;
    owner = msg.sender;
    timeCreated = block.timestamp;
  }

  /**
   * @dev Admin can set token's price
   * @param _price Price per token in wei.
   */
  function setTokenPrice(uint256 _price) onlyOwner {
      tokenPrice = _price;
  }

  /**
   * @dev Admin can set minimal amount of tokens user can have
   * @param _value minimal amount of tokens (will be multiplied of MULTIPLIER utomatically)
   */
  function setMinTokensAmount(uint256 _value) onlyOwner {
      minTokensAmount = _value * MULTIPLIER;
  }

  /**
   * @dev Admin can set maximum amount of tokens user can have
   * @param _value maximum amount of tokens (will be multiplied of MULTIPLIER utomatically)
   */
  function setMaxTokensAmount(uint256 _value) onlyOwner {
      maxTokensAmount = _value * MULTIPLIER;
  }

  /**
   * @dev Admin can set address of benefactor
   * @param _value address of benefactor
   */
  function setBenefactor(address _value) onlyOwner {
    require(_value != address(0));
    benefactor = _value;
  }

  /**
   * @dev Admin can set address of company
   * @param _value address of company
   */
  function setCompany(address _value) onlyOwner {
    require(_value != address(0));
    company = _value;
  }

  /**
   * @dev Admin can set address of consultants
   * @param _value addres of benefactor
   */
  function setConsultants(address _value) onlyOwner {
    require(_value != address(0));
    consultants = _value;
  }

  /**
   * @dev Admin can set address of advisory board
   * @param _value addres of advisory board
   */
  function setAdvisoryBoard(address _value) onlyOwner {
    require(_value != address(0));
    advisoryBoard = _value;
  }

  /**
   * @dev Admin can set address of bounty
   * @param _value addres of bounty
   */
  function setBounty(address _value) onlyOwner {
    require(_value != address(0));
    bounty = _value;
  }

  /**
   * @dev Admin can set address of infrostructure
   * @param _value addres of infrostructure
   */
  function setInfrostructure(address _value) onlyOwner {
    require(_value != address(0));
    infrostructure = _value;
  }

  /**
   * @dev Admin can set addresses of escrow sccounts
   * @param _escrow1 addres of escrow1
   * @param _escrow2 addres of escrow2
   * @param _escrow3 addres of escrow3
   */
  function setEscrow(address _escrow1, address _escrow2, address _escrow3) onlyOwner {
    require(_escrow1 != address(0));
    require(_escrow2 != address(0));
    require(_escrow3 != address(0));
    escrow1 = _escrow1;
    escrow2 = _escrow2;
    escrow3 = _escrow3;
  }

  /**
   * @dev Admin can set addresses of migration agent smart contract
   * @param _value addres of migration agent smart contract
   */
  function setMigrationAgent(address _value) onlyOwner {
    migrationAgent = _value;
  }

  /**
   * @dev Admin can set discount amount. investors receve amount + amount * buyDiscount / 100
   * @param _discount amount in percents
   */
  function setBuyDiscount(uint256 _discount) onlyOwner {
      buyDiscount = _discount;
  }

  /**
   * @dev User can buy tokens by calling this method and send ETH. Also referal address can be sended
   * @param _referal address of referal
   */
  function buy(address _referal) payable{
    //get amount of tokens investor will receive
    uint256 amount = msg.value * MULTIPLIER / tokenPrice;
    //add current discount
    amount = amount + amount * buyDiscount / 100;

    //checks
    require(tokenPrice != 0);
    require(_referal != msg.sender);
    if(_referal != address(0)){
      require(balances[owner] >= amount + amount * 7 / 100);
      require(balances[msg.sender] + amount + amount * 2 / 100 >= minTokensAmount);
      require(balances[msg.sender] + amount + amount * 2 / 100 <= maxTokensAmount);
      require(balances[_referal] + amount * 5 / 100 <= maxTokensAmount);

      //add tokens with 2% bonus
      balances[msg.sender] = balances[msg.sender].add(amount + amount * 2 / 100);
      //add 5% for referal
      balances[_referal] = balances[_referal].add(amount * 5 / 100);
      //sub from owner
      balances[owner] = balances[owner] - amount - amount * 7 / 100;
      //add to total amount of current stage
      tokensSoldInCurrentStage = tokensSoldInCurrentStage.add(amount + amount * 7 / 100);

      //fire events
      Transfer(owner, msg.sender, amount + amount * 2 / 100);
      Transfer(owner, _referal, amount * 5 / 100);

    }else{
      require(balances[owner] >= amount);
      require(balances[msg.sender] + amount >= minTokensAmount);
      require(balances[msg.sender] + amount <= maxTokensAmount);

      //add tokens to investor
      balances[msg.sender] = balances[msg.sender].add(amount);
      //sub from owner
      balances[owner] = balances[owner] - amount;
      //add to total amount of current stage
      tokensSoldInCurrentStage = tokensSoldInCurrentStage.add(amount);

      //fire event
      Transfer(owner, msg.sender, amount);
    }
  }

  /**
   * @dev Admin cann add tokens to investor
   * @param _to address of investor
   * @param _value amount of tokens will be added (will be NOT multiplied by MULTIPLIER)
   * @param _referal address of referal
   */
  function addTokens(address _to, uint256 _value, address _referal) onlyOwner returns (bool) {
    require(_to != address(0));
    //calculate tokens amount
    uint256 amount = _value;

    //checks
    if(address(0) != _referal){
      require(balances[_to] + amount + amount * 2 / 100 >= minTokensAmount);
      require(balances[_to] + amount + amount * 2 / 100 <= maxTokensAmount);
      require(balances[_referal] + amount * 5 / 100 <= maxTokensAmount);
      require(balances[owner] >= amount + amount * 7 / 100);
    }else {
      require(balances[_to] + amount >= minTokensAmount);
      require(balances[_to] + amount <= maxTokensAmount);
      require(balances[owner] >= amount);
    }

    if(address(0) != _referal)
    {
      //add tokens with 2% bonus
      balances[_to] = balances[_to].add(amount + amount * 2 / 100);
      //add 5% for referal
      balances[_referal] = balances[_referal].add(amount * 5 / 100);
      //sub from owner
      balances[owner] = balances[owner] - amount - amount * 7 / 100;
      //add to total amount of current stage
      tokensSoldInCurrentStage = tokensSoldInCurrentStage.add(amount + amount * 7 / 100);

      //fire events
      Transfer(owner, _to, amount + amount * 2 / 100);
      Transfer(owner, _referal, amount * 5 / 100);
    }else
    {
      //sub from owner
      balances[owner] -= amount;
      //add to investor
      balances[_to] = balances[_to].add(amount);
      //add to total amount of current stage
      tokensSoldInCurrentStage = tokensSoldInCurrentStage.add(amount);
      //fire event
      Transfer(owner, _to, amount);
    }

    return true;
  }

  /**
   * @dev Regualar transfer function with min max amounts checks
   * @param _to address of receiver
   * @param _value amount of tokens will be transfered (will be NOT multiplied by MULTIPLIER)
   */
  function transfer(address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));

    require(balances[msg.sender] >= _value);
    require(balances[msg.sender] - _value >= minTokensAmount);
    require(balances[_to] + _value >= minTokensAmount);
    require(balances[_to] + _value <= maxTokensAmount);

    balances[msg.sender] -= _value;
    balances[_to] = balances[_to].add(_value);
    Transfer(msg.sender, _to, _value);
    return true;
  }

  /**
   * @dev Regualar transfer function
   * @param _from address of sended
   * @param _to address of receiver
   * @param _value amount of tokens will be transfered (will be NOT multiplied by MULTIPLIER)
   */
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value <= balances[_from]);
    require(_value <= allowed[_from][msg.sender]);

    require(balances[_from] - _value >= minTokensAmount);
    require(balances[_to] + _value >= minTokensAmount);
    require(balances[_to] + _value <= maxTokensAmount);

    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    Transfer(_from, _to, _value);
    return true;
  }

  /**
   * @dev Regualar approve function
   */
  function approve(address _spender, uint256 _value) public returns (bool) {
    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
    return true;
  }

  /**
   * @dev Regualar allowance function
   */
  function allowance(address _owner, address _spender) public constant returns (uint256 remaining) {
    return allowed[_owner][_spender];
  }

  /**
   * @dev Regualar increaseApproval function
   */
  function increaseApproval (address _spender, uint _addedValue) external returns (bool success) {
    allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
    Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  /**
   * @dev Regualar decreaseApproval function
   */
  function decreaseApproval (address _spender, uint _subtractedValue) external returns (bool success) {
    uint oldValue = allowed[msg.sender][_spender];
    if (_subtractedValue > oldValue) {
      allowed[msg.sender][_spender] = 0;
    } else {
      allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
    }
    Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  /**
   * @dev Admin can increase current stage of ICO by calling this method
   */
  function nextStage() onlyOwner {
    //when ICO is finished this method is not available anymore
    require(stage < STAGE5);

    //calculate amount of total tokens for bonuses of current stage
    uint256 tokensForBonuses = INITIAL_SUPPLY * tokensSoldInCurrentStage / (TOKENS_FOR_SELLE * 100);

    //bonuses distribution
    balances[company] += 23 * tokensForBonuses;
    balances[advisoryBoard] += 28 * tokensForBonuses / 10;
    balances[consultants] += 3 * tokensForBonuses;
    balances[bounty] += 3 * tokensForBonuses;

    //reset tokensSoldInCurrentStage amount
    tokensSoldInCurrentStage = 0;
    //iterate current stage
    stage ++;
    //if it was last stage, then burn rest of tokens on owners account and define total earned ETH amount
    if(stage == STAGE5){
      balances[owner] = 0;
      totalEarnedEthBalance = this.balance;
    }
  }

  /**
   * @dev Admin can request withdrawal. After all escrow accounts approve it, transfer is done
   * @param _value amount to withdrowal in wei
   */
  function requestWithdrawal(uint256 _value) onlyOwner returns (bool){
    //check if benefactor is set
    require(benefactor != address(0));
    //we have limitiaion for withdrawals in 10% per month. this limitiation affects only after PRE-ICO stage
    if(stage > STAGE1){
      uint256 currentTime = block.timestamp;
      uint256 currentMonth = (currentTime - timeCreated) / 2592000;
      //check monthley limit for withdrawal
      require( ( currentMonth + 1 ) * totalEarnedEthBalance * 10 / 100 >= totalWithdrawalAmountInControl + _value);
    }
    //save requsted amount
    requestedWithdrawal = _value;
    //reset all acceptations from escorw accounts
    escrow1Accepted = false;
    escrow2Accepted = false;
    escrow3Accepted = false;
    return true;
  }

  /**
   * @dev Escrow account have to call this function to accept reqested withdrowal. ETH will be transfered to benefactor address
   */
  function acceptWithdrawal() external returns (bool){
    //check if request was done
    require(requestedWithdrawal > 0);
    //vote for withdrawal
    if(msg.sender == escrow1) escrow1Accepted = true;
    if(msg.sender == escrow2) escrow2Accepted = true;
    if(msg.sender == escrow3) escrow3Accepted = true;

    //checks all votes
    require( escrow1Accepted );
    require( escrow2Accepted );
    require( escrow3Accepted );

    if(!benefactor.send(requestedWithdrawal)){ return false; }
    //if stage is not PRE-ICO, iterate totalWithdrawalAmountInControl amount, to control 10% of monthly withdrawals
    if(stage > STAGE1) totalWithdrawalAmountInControl += requestedWithdrawal;

    ///reset all acceptations from escorw accounts
    escrow1Accepted = false;
    escrow2Accepted = false;
    escrow3Accepted = false;
    //reset requestedWithdrawal amount
    requestedWithdrawal = 0;
    return true;
  }

  event PayForLicense(address indexed from, uint256 indexed value, string indexed receiptId);
  /**
   * @dev Tokens holder can pay for license to use SRT service
   * @param _value amount of tokens (will be multiplied by MULTIPLIER)
   * @param _receiptId system Id of requested payment
   */
  function payForLicense(uint256 _value, string _receiptId) external returns (bool){
    uint256 value = _value * MULTIPLIER;
    require(balances[msg.sender] >= value);
    balances[msg.sender] -= value;
    //from each payment bonuses will be distributed
    uint256 bonus = value / 10;
    balances[company] += bonus;
    balances[infrostructure] += bonus;
    //fire event
    PayForLicense(msg.sender, value, _receiptId);
    return true;
  }

  /**
   * @dev Tokens holders can migrate to another smart contract if needed
   */
  function migrate() external {
    //check if migrationAgent is set
    require(migrationAgent != address(0));
    uint value = balances[msg.sender];
    balances[msg.sender] -= value;
    totalSupply -= value;
    MigrationAgent(migrationAgent).migrateFrom(msg.sender, value);
  }
}
