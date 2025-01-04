// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

contract EstateRegistry {
    enum FacilityState {
        AVAILABLE,
        IN_REPAIR,
        OUT_OF_COMMISSION
    }

    enum UnitStatus {
        AVAILABLE,
        RENTED,
        OUT_OF_COMMISSION
    }

    struct Facility {
        string facilityId;
        string facilityName;
        string description;
        uint256 quantity;
        FacilityState facilityState;
    }

    struct Unit {
        string unitId;
        string name;
        string description;
        UnitStatus unitStatus;
        Facility[] facilities;
    }

    struct Estate {
        address owner;
        string estateId;
        string name;
        string description;
        Unit[] units;
        mapping(string => uint256) unitIdToPrice;
    }

    mapping(string => Estate) public estates; // Map estate ID to Estate
    address public immutable owner;

    event EstateRegistered(string estateId, address indexed owner, string name);
    event EstateRemoved(string estateId);
    event FacilityAdded(string estateId, string facilityId);
    event FacilityModified(string estateId, string facilityId);
    event UnitAdded(string estateId, string unitId);
    event UnitModified(string estateId, string unitId);
    event EstateOwnerModified(string estateId, address newOwner);

    modifier onlyRegistryOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    constructor(address _owner) {
        owner = _owner;
    }

    function registerEstate(
        string memory estateId,
        string memory name,
        string memory description,
        address estateOwner
    ) external onlyRegistryOwner {
        require(estates[estateId].owner == address(0), "Estate already exists");

        estates[estateId].owner = estateOwner;
        estates[estateId].estateId = estateId;
        estates[estateId].name = name;
        estates[estateId].description = description;

        emit EstateRegistered(estateId, estateOwner, name);
    }

    function removeEstate(string memory estateId) external onlyRegistryOwner {
        require(estates[estateId].owner != address(0), "Estate does not exist");

        delete estates[estateId];

        emit EstateRemoved(estateId);
    }

    function addFacility(
        string memory estateId,
        string memory facilityId,
        string memory facilityName,
        string memory description,
        uint256 quantity
    ) external onlyRegistryOwner {
        Estate storage estate = estates[estateId];
        require(estate.owner != address(0), "Estate does not exist");

        Facility memory newFacility = Facility(
            facilityId,
            facilityName,
            description,
            quantity,
            FacilityState.AVAILABLE
        );
        estate.units[0].facilities.push(newFacility); // Add to first unit for simplicity

        emit FacilityAdded(estateId, facilityId);
    }

    function modifyFacility(
        string memory estateId,
        string memory facilityId,
        FacilityState newState
    ) external onlyRegistryOwner {
        Estate storage estate = estates[estateId];
        require(estate.owner != address(0), "Estate does not exist");

        // Find and modify the facility
        for (uint256 i = 0; i < estate.units[0].facilities.length; i++) {
            if (
                keccak256(bytes(estate.units[0].facilities[i].facilityId)) ==
                keccak256(bytes(facilityId))
            ) {
                estate.units[0].facilities[i].facilityState = newState;
                emit FacilityModified(estateId, facilityId);
                return;
            }
        }
        revert("Facility not found");
    }

    function addUnit(
        string memory estateId,
        string memory unitId,
        string memory name,
        string memory description
    ) external onlyRegistryOwner {
        Estate storage estate = estates[estateId];
        require(estate.owner != address(0), "Estate does not exist");

        // Create the unit directly in storage
        estate.units.push(); // This creates a new empty unit at the end of the array
        Unit storage newUnit = estate.units[estate.units.length - 1];

        // Initialize the unit's fields
        newUnit.unitId = unitId;
        newUnit.name = name;
        newUnit.description = description;
        newUnit.unitStatus = UnitStatus.AVAILABLE;
        // facilities array is automatically initialized as an empty dynamic array

        emit UnitAdded(estateId, unitId);
    }

    function modifyUnit(
        string memory estateId,
        string memory unitId,
        UnitStatus newStatus
    ) external onlyRegistryOwner {
        Estate storage estate = estates[estateId];
        require(estate.owner != address(0), "Estate does not exist");

        for (uint256 i = 0; i < estate.units.length; i++) {
            if (
                keccak256(bytes(estate.units[i].unitId)) ==
                keccak256(bytes(unitId))
            ) {
                estate.units[i].unitStatus = newStatus;
                emit UnitModified(estateId, unitId);
                return;
            }
        }
        revert("Unit not found");
    }

    function modifyEstateOwner(
        string memory estateId,
        address newOwner
    ) external onlyRegistryOwner {
        require(estates[estateId].owner != address(0), "Estate does not exist");

        estates[estateId].owner = newOwner;
        emit EstateOwnerModified(estateId, newOwner);
    }
}
