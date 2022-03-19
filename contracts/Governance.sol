// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/IProduct.sol";
import "./interfaces/ISesameCredit.sol";

contract Governance {
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet voters;
    EnumerableSet.AddressSet products;

    uint256 public sesamePrice;
    address public voterToAdd;
    address public voterToRemove;
    address public productToAdd;
    address public productToRemove;

    address public immutable randomNumberGenerator;
    address public immutable feeCollector;
    address public immutable accountant;
    address public immutable sesameCredit;

    EnumerableSet.AddressSet approveAddVoter;
    EnumerableSet.AddressSet approveRemoveVoter;
    EnumerableSet.AddressSet approveAddProduct;
    EnumerableSet.AddressSet approveRemoveProduct;
    EnumerableSet.AddressSet approveSesameCredit;

    event ApproveAddVoter(address indexed by, address indexed voter);
    event ApproveRemoveVoter(address indexed by, address indexed voter);
    event ApproveAddProduct(address indexed by, address indexed product);
    event ApproveRemoveProduct(address indexed by, address indexed product);
    event ApproveSesameCredit(address indexed by, uint256 price);

    event AddVoter(address indexed voter);
    event RemoveVoter(address indexed voter);
    event AddProduct(address indexed product);
    event RemoveProduct(address indexed product);
    event SetSesameCredit(uint256 price);

    modifier onlyVoter() {
        require(voters.contains(msg.sender), "UNAUTHORIZED");
        _;
    }

    constructor(
        address _feeCollector,
        address _randomNumberGenerator,
        address _accountant,
        address _sesameCredit
    ) {
        voters.add(msg.sender);
        feeCollector = _feeCollector;
        randomNumberGenerator = _randomNumberGenerator;
        accountant = _accountant;
        sesameCredit = _sesameCredit;
    }

    function voterAt(uint256 index) public view returns (address) {
        return voters.at(index);
    }

    function isVoter(address _voter) public view returns (bool) {
        return voters.contains(_voter);
    }

    function productAt(uint256 index) public view returns (address) {
        return products.at(index);
    }

    function isProduct(address _product) public view returns (bool) {
        return products.contains(_product);
    }

    function voterCount() public view returns (uint256) {
        return voters.length();
    }

    function reset(EnumerableSet.AddressSet storage set) internal {
        uint256 size = set.length();
        for (uint256 i = 0; i < size; i++) {
            set.remove(set.at(0));
        }
    }

    function isAddVoterApproved(address _by) public view returns (bool) {
        return approveAddVoter.contains(_by);
    }

    function isRemoveVoterApproved(address _by) public view returns (bool) {
        return approveRemoveVoter.contains(_by);
    }

    function isAddProductApproved(address _by) public view returns (bool) {
        return approveAddProduct.contains(_by);
    }

    function isRemoveProductApproved(address _by) public view returns (bool) {
        return approveRemoveProduct.contains(_by);
    }

    function isSesameCreditApproved(address _by) public view returns (bool) {
        return approveSesameCredit.contains(_by);
    }

    function addVoter(address _voter) public onlyVoter {
        require(_voter != address(0), "ZERO ADDRESS");
        require(!voters.contains(_voter), "NOOP");
        if (voterToAdd != _voter) {
            voterToAdd = _voter;
            reset(approveAddVoter);
        }

        approveAddVoter.add(msg.sender);
        emit ApproveAddVoter(msg.sender, _voter);
        if (approveAddVoter.length() == voters.length()) {
            voters.add(_voter);
            reset(approveAddVoter);
            voterToAdd = address(0);
            emit AddVoter(_voter);
        }
    }

    function removeVoter(address _voter) public onlyVoter {
        require(voters.contains(_voter), "NOT FOUND");
        require(msg.sender != _voter, "UNAUTHORIZED");
        require(voters.length() > 2, "BAD REQUEST");
        if (voterToRemove != _voter) {
            voterToRemove = _voter;
            reset(approveRemoveVoter);
        }

        approveRemoveVoter.add(msg.sender);
        emit ApproveRemoveVoter(msg.sender, _voter);
        if (approveRemoveVoter.length() == voters.length() - 1) {
            voters.remove(_voter);
            reset(approveRemoveVoter);
            voterToRemove = address(0);
            emit RemoveVoter(_voter);
        }
    }

    function addProduct(address _product) public onlyVoter {
        require(_product != address(0), "ZERO ADDRESS");
        require(!products.contains(_product), "NOOP");
        if (productToAdd != _product) {
            productToAdd = _product;
            reset(approveAddProduct);
        }

        approveAddProduct.add(msg.sender);
        emit ApproveAddProduct(msg.sender, _product);
        if (approveAddProduct.length() == voters.length()) {
            products.add(_product);
            IProduct(_product).activate();
            reset(approveAddProduct);
            productToAdd = address(0);
            emit AddProduct(_product);
        }
    }

    function removeProduct(address _product) public onlyVoter {
        require(products.contains(_product), "NOT FOUND");
        if (productToRemove != _product) {
            productToRemove = _product;
            reset(approveRemoveProduct);
        }

        approveRemoveProduct.add(msg.sender);
        emit ApproveRemoveProduct(msg.sender, _product);
        if (approveRemoveProduct.length() == voters.length()) {
            products.remove(_product);
            IProduct(_product).deactivate();
            reset(approveRemoveProduct);
            productToRemove = address(0);
            emit RemoveProduct(_product);
        }
    }

    function setSesameCredit(uint256 _price) public onlyVoter {
        if (sesamePrice != _price) {
            sesamePrice = _price;
            reset(approveSesameCredit);
        }

        approveSesameCredit.add(msg.sender);
        emit ApproveSesameCredit(msg.sender, _price);
        if (approveSesameCredit.length() == voters.length()) {
            ISesameCredit(sesameCredit).updateAnswer(int256(_price));
            reset(approveSesameCredit);
            emit SetSesameCredit(_price);
        }
    }
}
