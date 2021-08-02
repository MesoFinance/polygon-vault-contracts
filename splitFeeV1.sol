//"SPDX-License-Identifier: UNLICENSED"
pragma solidity ^0.8.6;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";


interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}


interface IUniswapRouterV2 {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);
}
 

contract splitFee is Ownable, ReentrancyGuard {
  using SafeMath for uint16;
  using SafeMath for uint256; 
  using SafeERC20 for IERC20;
  
  constructor(){}
  
  address public insurance = 0x2F6Cf5B34020349811adF49E76aC6bc5184d7d84;
  address public treasury = 0x143171E36172cb631E26D925484Be761F2B83f0d; 
  address public usdc = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
  
  uint16 public insurancePercentage = 2000; // In basis points
  uint16 public treasuryPercentage = 8000; // In basis points
  
  address[] public dustToken_usdc_path;

  address public currentRouter = 0x0000000000000000000000000000000000000000;

  event routerUpdated(address _router);


  function updateRouter(address _router) public onlyOwner {
    
    currentRouter = _router;
    emit routerUpdated(_router);
      
  }

  
  function _swapUniswapWithPath(address[] memory path, uint256 _amount) internal {
    
    require(path[1] != address(0));

    // Swap with uniswap
    IERC20(path[0]).safeApprove(currentRouter, 0);
    IERC20(path[0]).safeApprove(currentRouter, _amount);

    IUniswapRouterV2(currentRouter).swapExactTokensForTokens(
      _amount,
      0,
      path,
      address(this),
      (block.timestamp).add(60)
      );
  }


  function _swapUniswapWithPathForFeeOnTransferTokens(address[] memory path, uint256 _amount) internal {
    require(path[1] != address(0));

    // Swap with uniswap
    IERC20(path[0]).safeApprove(currentRouter, 0);
    IERC20(path[0]).safeApprove(currentRouter, _amount);

    IUniswapRouterV2(currentRouter).swapExactTokensForTokensSupportingFeeOnTransferTokens(
      _amount,
      0,
      path,
      address(this),
      (block.timestamp).add(60)
    );
  }


  function withdraw() public nonReentrant {
    
    uint256 profit = IERC20(usdc).balanceOf(address(this));
    uint256 insuranceFee = profit.mul(insurancePercentage).div(10000);
    uint256 treasuryFee = (profit.sub(insuranceFee));

    if(profit>0) {

      // Transfer of fees to the Insurance contract of the platform
      IERC20(usdc).safeTransfer(insurance, insuranceFee);

      // Transfer of fees to the Treasury contract of the platform
      IERC20(usdc).safeTransfer(treasury, treasuryFee);

    }
  }


  function convertDust(address _address) public onlyOwner nonReentrant {
    require (_address != address(0) || _address != usdc, "Not valid token address");
    
    uint256 checkBalance = IERC20(_address).balanceOf(address(this));

    if (checkBalance > 0) {
      
      address dustToken = _address;
        
      dustToken_usdc_path = new address[](2);
      dustToken_usdc_path[0] = dustToken;
      dustToken_usdc_path[1] = usdc;
      
      _swapUniswapWithPath(dustToken_usdc_path, checkBalance);
    
    }
        
  }


}
