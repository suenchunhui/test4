// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title NFTMarketplace
 * @dev A smart contract for an NFT marketplace where users can buy and sell ERC721 tokens.
 */
contract NFTMarketplace is ERC721Holder {
    using SafeMath for uint256;
    
    // Struct to store the details of a listing
    struct Listing {
        uint256 listingId;
        address seller;
        address tokenContract;
        uint256 tokenId;
        uint256 price;
        bool isActive;
    }
    
    // Arrays to store the listings and sale statistics
    Listing[] private listings;
    uint256 private totalListings;
    uint256 private totalSales;
    
    // Mapping to keep track of NFT ownership
    mapping(address => mapping(uint256 => bool)) private nftOwnership;
    
    // Variables to store the marketplace fee and fee collector address
    uint256 private feePercentage;
    address private feeCollector;
    
    // Events
    event NFTListed(uint256 listingId, address indexed seller, address indexed tokenContract, uint256 indexed tokenId, uint256 price);
    event NFTSold(uint256 listingId, address indexed buyer, address indexed tokenContract, uint256 indexed tokenId, uint256 price);
    event NFTPriceChanged(uint256 listingId, uint256 newPrice);
    event NFTUnlisted(uint256 listingId);
    
    constructor() {
        feePercentage = 1; // Default fee percentage is 1%
        feeCollector = msg.sender; // Fee collector is contract deployer
    }
    
    /**
     * @dev Function to list an ERC721 NFT for sale on the marketplace.
     * @param _tokenContract The address of the ERC721 token contract.
     * @param _tokenId The ID of the token being listed.
     * @param _price The sale price for the token.
     */
    function listNFT(address _tokenContract, uint256 _tokenId, uint256 _price) external {
        require(_tokenContract != address(0), "Invalid token contract address");
        require(_tokenId > 0, "Invalid token ID");
        require(_price > 0, "Invalid price");
        require(IERC721(_tokenContract).ownerOf(_tokenId) == msg.sender, "You do not own this NFT");
        
        uint256 listingId = totalListings.add(1);
        nftOwnership[_tokenContract][_tokenId] = true;
        
        listings.push(Listing({
            listingId: listingId,
            seller: msg.sender,
            tokenContract: _tokenContract,
            tokenId: _tokenId,
            price: _price,
            isActive: true
        }));
        
        totalListings = totalListings.add(1);
        
        emit NFTListed(listingId, msg.sender, _tokenContract, _tokenId, _price);
    }
    
    /**
     * @dev Function to buy an ERC721 NFT listed on the marketplace.
     * @param _listingId The ID of the listing to buy.
     */
    function buyNFT(uint256 _listingId) external payable {
        require(_listingId > 0 && _listingId <= totalListings, "Invalid listing ID");
        
        Listing storage listing = listings[_listingId.sub(1)];
        
        require(listing.isActive, "Listing is not active");
        require(msg.value >= listing.price, "Insufficient payment");
        
        address tokenContract = listing.tokenContract;
        uint256 tokenId = listing.tokenId;
        address seller = listing.seller;
        
        IERC721(tokenContract).safeTransferFrom(address(this), msg.sender, tokenId);
        
        // Transfer payment to seller
        (bool success, ) = seller.call{value: listing.price}("");
        require(success, "Payment transfer failed");
        
        // Distribute fee to fee collector
        uint256 feeAmount = listing.price.mul(feePercentage).div(100);
        (success, ) = feeCollector.call{value: feeAmount}("");
        require(success, "Fee transfer failed");
        
        listing.isActive = false;
        totalSales = totalSales.add(1);
        
        emit NFTSold(_listingId, msg.sender, tokenContract, tokenId, listing.price);
    }
    
    /**
     * @dev Function to change the price of a listed NFT.
     * @param _listingId The ID of the listing to change the price for.
     * @param _newPrice The new price for the NFT.
     */
    function changePrice(uint256 _listingId, uint256 _newPrice) external {
        require(_listingId > 0 && _listingId <= totalListings, "Invalid listing ID");
        require(_newPrice > 0, "Invalid price");
        
        Listing storage listing = listings[_listingId.sub(1)];
        
        require(listing.isActive, "Listing is not active");
        require(listing.seller == msg.sender, "You are not the seller of this NFT");
        
        listing.price = _newPrice;
        
        emit NFTPriceChanged(_listingId, _newPrice);
    }
    
    /**
     * @dev Function to remove a listing from the marketplace.
     * @param _listingId The ID of the listing to remove.
     */
    function unlistNFT(uint256 _listingId) external {
        require(_listingId > 0 && _listingId <= totalListings, "Invalid listing ID");
        
        Listing storage listing = listings[_listingId.sub(1)];
        
        require(listing.isActive, "Listing is not active");
        require(listing.seller == msg.sender, "You are not the seller of this NFT");
        
        listing.isActive = false;
        
        emit NFTUnlisted(_listingId);
    }
    
    /**
     * @dev Function to get the total number of listings.
     * @return The total number of listings.
     */
    function getTotalListings() external view returns (uint256) {
        return totalListings;
    }
    
    /**
     * @dev Function to get the total number of NFT sales.
     * @return The total number of NFT sales.
     */
    function getTotalSales() external view returns (uint256) {
        return totalSales;
    }
    
    /**
     * @dev Function to get the details of a listing.
     * @param _listingId The ID of the listing to get the details of.
     * @return The seller, token contract address, token ID, price, and active status of the listing.
     */
    function getListing(uint256 _listingId) external view returns (address, address, uint256, uint256, bool) {
        require(_listingId > 0 && _listingId <= totalListings, "Invalid listing ID");
        
        Listing memory listing = listings[_listingId.sub(1)];
        
        return (listing.seller, listing.tokenContract, listing.tokenId, listing.price, listing.isActive);
    }
    
    /**
    * @dev Function to change the fee percentage and fee collector address.
    * @param _feePercentage The new fee percentage.
    * @param _feeCollector The new fee collector address.
    */
    function updateFeeSettings(uint256 _feePercentage, address _feeCollector) external {
        require(msg.sender == feeCollector, "Only fee collector can update fee settings");
        require(_feeCollector != address(0), "Invalid fee collector address");
        
        feePercentage = _feePercentage;
        feeCollector = _feeCollector;
    }
    
    /**
     * @dev Function to retrieve the current fee percentage.
     * @return The current fee percentage.
     */
    function getFeePercentage() external view returns (uint256) {
        return feePercentage;
    }
    
    /**
     * @dev Function to retrieve the current fee collector address.
     * @return The current fee collector address.
     */
    function getFeeCollector() external view returns (address) {
        return feeCollector;
    }
}