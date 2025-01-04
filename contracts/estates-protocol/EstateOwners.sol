// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

contract EstateOwners {
    enum UnitStatus {
        LISTED,
        OWNED
    }

    struct Unit {
        uint256 price; // Price per ownership unit in wei
        uint256 quantity; // Quantity of ownership units
        UnitStatus status; // Current status of the unit
        address owner; // Current owner of the unit
    }

    uint256 public totalUnits = 100; // Total ownership units
    uint256 public totalListedUnits = 100; // Units available for purchase
    uint256 public lastWithdrawalTime; // Timestamp of the last withdrawal
    uint256 public withdrawalInterval = 30 days; // Interval between withdrawals

    mapping(uint256 => Unit) public unitDetails; // Map unit ID to unit details
    address[] public owners; // List of unique owners
    mapping(address => uint256) public ownerShares; // Map owner address to their share of units
    mapping(address => uint256) public ownerWithdrawn; // Tracks how much each owner has withdrawn

    event UnitsListed(uint256 unitId, uint256 price, uint256 quantity);
    event UnitsBought(
        uint256 unitId,
        address buyer,
        uint256 quantity,
        uint256 totalPrice
    );
    event UnitsDelisted(uint256 unitId);
    event EarningsClaimed(address indexed owner, uint256 amount);

    modifier onlyUnitOwner(uint256 unitId) {
        require(unitDetails[unitId].owner == msg.sender, "Not the unit owner");
        _;
    }

    /**
     * @dev Lists a unit for sale.
     * @param unitId The ID of the unit being listed.
     * @param price The price per ownership unit (in wei).
     * @param quantity The number of ownership units available.
     */
    function listUnits(
        uint256 unitId,
        uint256 price,
        uint256 quantity
    ) external {
        require(unitDetails[unitId].quantity == 0, "Unit already exists");
        require(
            quantity <= totalListedUnits,
            "Exceeds available ownership units"
        );

        unitDetails[unitId] = Unit(
            price,
            quantity,
            UnitStatus.LISTED,
            address(0)
        );
        totalListedUnits -= quantity;

        emit UnitsListed(unitId, price, quantity);
    }

    /**
     * @dev Allows a user to buy ownership units.
     * @param unitId The ID of the unit being purchased.
     */
    function buyUnits(uint256 unitId) external payable {
        Unit storage unit = unitDetails[unitId];
        require(unit.status == UnitStatus.LISTED, "Unit not listed");
        require(msg.value == unit.price / 1 ether, "Incorrect payment amount");

        // Update ownership details
        ownerShares[msg.sender] += unit.quantity;
        if (!isOwner(msg.sender)) {
            owners.push(msg.sender);
        }

        emit UnitsBought(unitId, msg.sender, unit.quantity, msg.value);
    }

    /**
     * @dev Allows an owner to claim their earnings.
     */
    function claimEarnings() external {
        require(
            block.timestamp >= lastWithdrawalTime + withdrawalInterval,
            "Withdrawals not yet allowed"
        );
        require(ownerShares[msg.sender] > 0, "You own no shares");

        uint256 totalEarnings = address(this).balance;
        require(totalEarnings > 0, "No earnings to withdraw");

        // Calculate the owner's share based on their ownership percentage
        uint256 ownerShare = (ownerShares[msg.sender] * totalEarnings) /
            totalUnits;

        // Transfer the calculated amount
        payable(msg.sender).transfer(ownerShare);

        emit EarningsClaimed(msg.sender, ownerShare);
    }

    /**
     * @dev Delists a unit, making it unavailable for purchase.
     * @param unitId The ID of the unit to delist.
     */
    function delistUnits(uint256 unitId) external onlyUnitOwner(unitId) {
        Unit storage unit = unitDetails[unitId];
        require(unit.status == UnitStatus.LISTED, "Unit not listed");

        // Return the quantity to the total listed units
        totalListedUnits += unit.quantity;
        unit.status = UnitStatus.OWNED;

        emit UnitsDelisted(unitId);
    }

    /**
     * @dev Checks if an address is an owner.
     * @param _owner The address to check.
     * @return bool Whether the address is an owner.
     */
    function isOwner(address _owner) internal view returns (bool) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == _owner) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Returns the number of unsold units.
     * @return uint256 The number of unsold units.
     */
    function getUnsoldUnits() public view returns (uint256) {
        return totalListedUnits;
    }

    receive() external payable {}
}
