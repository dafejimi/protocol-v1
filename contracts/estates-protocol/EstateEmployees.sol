// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

contract EstateEmployees {
    enum ROLES {
        CEO,
        SPM, // Senior Property Manager
        PM, // Property Manager
        FM // Facility Manager
    }

    struct Employee {
        address employeeAddress; // Address of the employee
        ROLES role; // Role of the employee
        uint256 salary; // Salary of the employee in wei
        uint256 lastWithdrawal; // Timestamp of the last salary withdrawal
        bool active; // Whether the employee is active
    }

    mapping(address => Employee) public employees; // Employee details
    address[] public employeeList; // List of all employee addresses
    uint256 public withdrawalInterval = 30 days; // Interval between salary withdrawals

    address public owner; // Owner of the contract

    event EmployeeAdded(address indexed employee, ROLES role, uint256 salary);
    event EmployeeRemoved(address indexed employee);
    event SalaryWithdrawn(address indexed employee, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier onlyActiveEmployee() {
        require(employees[msg.sender].active, "Not an active employee");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Adds a new employee.
     * @param _employee The address of the employee.
     * @param _role The role of the employee.
     * @param _salary The salary of the employee in wei.
     */
    function addEmployee(
        address _employee,
        ROLES _role,
        uint256 _salary
    ) external onlyOwner {
        require(
            employees[_employee].employeeAddress == address(0),
            "Employee already exists"
        );

        employees[_employee] = Employee({
            employeeAddress: _employee,
            role: _role,
            salary: _salary,
            lastWithdrawal: block.timestamp - withdrawalInterval, // Allow immediate withdrawal
            active: true
        });
        employeeList.push(_employee);

        emit EmployeeAdded(_employee, _role, _salary);
    }

    /**
     * @dev Removes an employee from the active list.
     * @param _employee The address of the employee to remove.
     */
    function removeEmployee(address _employee) external onlyOwner {
        require(
            employees[_employee].active,
            "Employee does not exist or already inactive"
        );

        employees[_employee].active = false;

        emit EmployeeRemoved(_employee);
    }

    /**
     * @dev Allows employees to withdraw their salaries periodically.
     */
    function withdrawSalary() external onlyActiveEmployee {
        Employee storage employee = employees[msg.sender];

        require(
            block.timestamp >= employee.lastWithdrawal + withdrawalInterval,
            "Withdrawal not allowed yet"
        );

        require(
            address(this).balance >= employee.salary,
            "Insufficient contract balance"
        );

        employee.lastWithdrawal = block.timestamp;
        payable(employee.employeeAddress).transfer(employee.salary);

        emit SalaryWithdrawn(employee.employeeAddress, employee.salary);
    }

    /**
     * @dev Funds the contract to pay salaries.
     */
    function fundContract() external payable onlyOwner {
        require(msg.value > 0, "Must send funds to pay salaries");
    }

    /**
     * @dev Returns the list of all employees.
     */
    function getEmployees() external view returns (Employee[] memory) {
        Employee[] memory activeEmployees = new Employee[](employeeList.length);
        uint256 counter = 0;

        for (uint256 i = 0; i < employeeList.length; i++) {
            address employeeAddress = employeeList[i];
            if (employees[employeeAddress].active) {
                activeEmployees[counter] = employees[employeeAddress];
                counter++;
            }
        }
        return activeEmployees;
    }

    receive() external payable {}
}
