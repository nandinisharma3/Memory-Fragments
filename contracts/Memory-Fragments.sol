// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Memory-Fragments
 * @dev A decentralized platform for preserving and sharing digital memories
 * @author Memory-Fragments Team
 */
contract Project {
    // Structure to represent a memory fragment
    struct MemoryFragment {
        uint256 id;
        address owner;
        string title;
        string contentHash; // IPFS hash for storing actual content
        string description;
        uint256 timestamp;
        bool isPublic;
        bool isPreserved;
        uint256 preservationFee;
    }
    
    // Structure for memory access permissions
    struct AccessPermission {
        address grantedTo;
        uint256 expirationTime;
        bool canEdit;
    }
    
    // State variables
    mapping(uint256 => MemoryFragment) public memoryFragments;
    mapping(uint256 => mapping(address => AccessPermission)) public accessPermissions;
    mapping(address => uint256[]) public userMemories;
    
    uint256 public nextMemoryId;
    uint256 public constant PRESERVATION_BASE_FEE = 0.001 ether;
    address public platformOwner;
    uint256 public totalMemoriesStored;
    
    // Events
    event MemoryCreated(
        uint256 indexed memoryId,
        address indexed owner,
        string title,
        bool isPublic
    );
    
    event MemoryPreserved(
        uint256 indexed memoryId,
        address indexed owner,
        uint256 preservationFee
    );
    
    event AccessGranted(
        uint256 indexed memoryId,
        address indexed owner,
        address indexed grantedTo,
        uint256 expirationTime
    );
    
    // Modifiers
    modifier onlyMemoryOwner(uint256 _memoryId) {
        require(
            memoryFragments[_memoryId].owner == msg.sender,
            "Only memory owner can perform this action"
        );
        _;
    }
    
    modifier memoryExists(uint256 _memoryId) {
        require(
            memoryFragments[_memoryId].owner != address(0),
            "Memory fragment does not exist"
        );
        _;
    }
    
    modifier hasAccess(uint256 _memoryId) {
        MemoryFragment memory fragment = memoryFragments[_memoryId];
        require(
            fragment.owner == msg.sender ||
            fragment.isPublic ||
            (accessPermissions[_memoryId][msg.sender].grantedTo == msg.sender &&
             accessPermissions[_memoryId][msg.sender].expirationTime > block.timestamp),
            "Access denied to this memory fragment"
        );
        _;
    }
    
    constructor() {
        platformOwner = msg.sender;
        nextMemoryId = 1;
    }
    
    /**
     * @dev Core Function 1: Create and store a new memory fragment
     * @param _title Title of the memory
     * @param _contentHash IPFS hash of the memory content
     * @param _description Description of the memory
     * @param _isPublic Whether the memory is publicly accessible
     */
    function createMemory(
        string memory _title,
        string memory _contentHash,
        string memory _description,
        bool _isPublic
    ) external returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_contentHash).length > 0, "Content hash cannot be empty");
        
        uint256 memoryId = nextMemoryId;
        
        memoryFragments[memoryId] = MemoryFragment({
            id: memoryId,
            owner: msg.sender,
            title: _title,
            contentHash: _contentHash,
            description: _description,
            timestamp: block.timestamp,
            isPublic: _isPublic,
            isPreserved: false,
            preservationFee: 0
        });
        
        userMemories[msg.sender].push(memoryId);
        totalMemoriesStored++;
        nextMemoryId++;
        
        emit MemoryCreated(memoryId, msg.sender, _title, _isPublic);
        
        return memoryId;
    }
    
    /**
     * @dev Core Function 2: Preserve a memory fragment permanently with fee
     * @param _memoryId ID of the memory to preserve
     */
    function preserveMemory(uint256 _memoryId) 
        external 
        payable 
        memoryExists(_memoryId) 
        onlyMemoryOwner(_memoryId) 
    {
        require(!memoryFragments[_memoryId].isPreserved, "Memory already preserved");
        require(msg.value >= PRESERVATION_BASE_FEE, "Insufficient preservation fee");
        
        memoryFragments[_memoryId].isPreserved = true;
        memoryFragments[_memoryId].preservationFee = msg.value;
        
        emit MemoryPreserved(_memoryId, msg.sender, msg.value);
    }
    
    /**
     * @dev Core Function 3: Grant access to a memory fragment
     * @param _memoryId ID of the memory
     * @param _grantTo Address to grant access to
     * @param _duration Duration of access in seconds
     * @param _canEdit Whether the granted user can edit the memory
     */
    function grantAccess(
        uint256 _memoryId,
        address _grantTo,
        uint256 _duration,
        bool _canEdit
    ) external memoryExists(_memoryId) onlyMemoryOwner(_memoryId) {
        require(_grantTo != address(0), "Cannot grant access to zero address");
        require(_grantTo != msg.sender, "Cannot grant access to yourself");
        require(_duration > 0, "Duration must be greater than 0");
        
        uint256 expirationTime = block.timestamp + _duration;
        
        accessPermissions[_memoryId][_grantTo] = AccessPermission({
            grantedTo: _grantTo,
            expirationTime: expirationTime,
            canEdit: _canEdit
        });
        
        emit AccessGranted(_memoryId, msg.sender, _grantTo, expirationTime);
    }
    
    // View functions
    function getMemory(uint256 _memoryId) 
        external 
        view 
        memoryExists(_memoryId) 
        hasAccess(_memoryId) 
        returns (MemoryFragment memory) 
    {
        return memoryFragments[_memoryId];
    }
    
    function getUserMemories(address _user) external view returns (uint256[] memory) {
        return userMemories[_user];
    }
    
    function checkAccess(uint256 _memoryId, address _user) 
        external 
        view 
        memoryExists(_memoryId) 
        returns (bool hasAccessRight, bool canEdit, uint256 expirationTime) 
    {
        MemoryFragment memory fragment = memoryFragments[_memoryId];
        
        if (fragment.owner == _user || fragment.isPublic) {
            return (true, fragment.owner == _user, 0);
        }
        
        AccessPermission memory permission = accessPermissions[_memoryId][_user];
        if (permission.grantedTo == _user && permission.expirationTime > block.timestamp) {
            return (true, permission.canEdit, permission.expirationTime);
        }
        
        return (false, false, 0);
    }
    
    function getPlatformStats() external view returns (
        uint256 totalMemories,
        uint256 nextId,
        address owner
    ) {
        return (totalMemoriesStored, nextMemoryId, platformOwner);
    }
    
    // Platform owner functions
    function withdrawFees() external {
        require(msg.sender == platformOwner, "Only platform owner can withdraw");
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        
        payable(platformOwner).transfer(balance);
    }
    
    function updatePreservationFee(uint256 _newFee) external {
        require(msg.sender == platformOwner, "Only platform owner can update fee");
        // Note: This would require a more sophisticated upgrade mechanism in production
    }
}
