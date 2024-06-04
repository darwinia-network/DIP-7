pragma solidity >=0.4.24;

interface ICollatorStakingPool {
    // Views
    function operator() external view returns (address);

    function lastTimeRewardApplicable() external view returns (uint256);

    function rewardPerToken() external view returns (uint256);

    function earned(address account) external view returns (uint256);

    function getRewardForDuration() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    // Mutative

    function stake(address account, uint256 assets) external;

    function withdraw(address account, uint256 assets) external;

    function getReward(address account) external;

    function notifyRewardAmount() external payable;
}
