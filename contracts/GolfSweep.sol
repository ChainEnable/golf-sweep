// SPDX-License-Identifier: MIT
pragma solidity 0.8.1;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract GolfSweep is  ERC721Enumerable, ReentrancyGuard, Ownable {

    bool public _whitelistOnly;
    uint256 public constant MAX_SUPPLY = 99; // Maximum supply of 99
    uint256 public _price; // Price per token
    uint256 public _maxPerWallet; // Maximum number of tokens that can be minted in one request
    mapping(address => bool) public _whitelist;
    mapping(uint256 => uint256) private _allocatedTokens; // Mapping to keep track of allocated tokens and help with the random allocation

    /**
     * @dev Constructor
     *
     * @param name_ name of the token
     * @param symbol_ symbol of the token
     * @param price_ price per token
     * @param maxPerWallet_ maximum tokens to be minted to a single address
     */
    constructor(
        string memory name_, 
        string memory symbol_,
        uint256 price_,
        uint256 maxPerWallet_) ERC721(name_, symbol_){
        _price = price_;
        _maxPerWallet = maxPerWallet_;
        _whitelistOnly = true;
    }

    /**
     * @dev Adds a list of addresses to the whitelist.      
     *
     * @param addressList_ address array to add to the whitelist
     */
    function addToWhitelist(address[] memory addressList_) external onlyOwner {
        for(uint256 i = 0; i < addressList_.length; i++)
            _whitelist[addressList_[i]] = true;
    }

    /**
     * @dev withdraws the eth from the contract to the supplied treasury address
     *
     * @param treasury_ treasury address for the eth to be sent to
     */
    function withdraw(address treasury_) external onlyOwner nonReentrant {
		payable(treasury_).transfer(address(this).balance);
	}


    /**
     * @dev toggles whitelist only flag
     *
     */
    function toggleWhitelist() external onlyOwner {
        _whitelistOnly = !_whitelistOnly;
	}

    /**
     * @dev sets max to mint per wallet
     *
     * @param maxPerWallet_ max amount per wallet to mint
     */
    function setMaxPerWallet(uint256 maxPerWallet_) external onlyOwner {
		_maxPerWallet = maxPerWallet_;
	}

    /**
     * @dev sets mint price
     *
     * @param newMintPrice_ new price per token
     */
    function setMintPrice(uint256 newMintPrice_) external onlyOwner {
		_price = newMintPrice_;
	}

    /**
     * @dev gets an amount an address can mint
     *
     * @param account_ address to check
     */
    function getMintableAmountForAddress(address account_) external view returns (uint256){        
        return _maxPerWallet - balanceOf(account_);
    }

    /**
     * @dev run some shared validation before minting
     *
     * @param quantity_ number of tokens to be minted     
     * @param to_ address to be minted to
     */
    function mintCheck(uint quantity_, address to_) internal view {
        require(!_whitelistOnly || _whitelist[to_], "Not on the whitelist");
        require((balanceOf(to_) + quantity_) <= _maxPerWallet, "Not enough allocation to mint");
        require(MAX_SUPPLY >= (totalSupply() + quantity_), "Mint would exceed max supply");
        require(msg.value >= (_price * quantity_), "Not enough eth");
    }


 
    /**
     * @dev Mints a quantity of tokens to the sender address
     *
     * @param quantity_ number of tokens to be minted
     */
    function mint(uint quantity_) external payable nonReentrant {
        mintCheck(quantity_, msg.sender);
        _randomMint(_random(), msg.sender, quantity_);
    }

    /**
     * @dev Override the base _baseURI() to set the IPFS location.
     *
     * @return string IPFS uri
     */
    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://<IPFSHASH>/";
    }

    /**
     * @dev Creates a random string to seed the mint tokens
     */
    function _random() internal view returns (uint256) {
        return uint256(
            keccak256(
                abi.encode(
                    msg.sender,
                    tx.gasprice,
                    block.number,
                    block.timestamp,
                    blockhash(block.number - 1),
                    block.difficulty
                )
            )
        );
    }

    /**
     * @dev random mint using a randomness seed
     *
     * @param randomness_ the random result
     */
    function _randomMint(uint256 randomness_, address to, uint256 amount) internal {

        // Calculate the remaining tokens and calculate an available index
        uint256 remaining =  MAX_SUPPLY - totalSupply();

        // loop through each token requested
        for(uint x = 0; x < amount; x++){
            require(remaining > 0);
            uint256 i = uint256(keccak256(abi.encode(randomness_, x))) % remaining;
            uint256 index = _allocatedTokens[i] == 0 ? i : _allocatedTokens[i];
            _allocatedTokens[i] = _allocatedTokens[remaining - 1] == 0 ? remaining - 1 : _allocatedTokens[remaining - 1];
            
            _safeMint(to, index + 1); // no zero token id

            remaining--; // OK as check is at start of loop
            
        }

    }

    /**
     * @dev to receive eth
     */
    receive() external payable {}
}
