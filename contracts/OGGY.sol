/**
 *Submitted for verification at Etherscan.io on 2023-04-02
 */

// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.19;

interface IBEP20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _setOwner(_msgSender());
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IFactory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

interface IRouter {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

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
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

library Address {
    function sendValue(address payable recipient, uint256 amount) internal {
        require(
            address(this).balance >= amount,
            "Address: insufficient balance"
        );

        (bool success, ) = recipient.call{value: amount}("");
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
    }
}

contract OGGY is Context, IBEP20, Ownable {
    //
    using Address for address payable;
    // r值
    mapping(address => uint256) public _rOwned;
    // t值
    mapping(address => uint256) public _tOwned;
    // ERC20
    mapping(address => mapping(address => uint256)) public _allowances;
    // 免费权限
    mapping(address => bool) public _isExcludedFromFee;
    // 分红权限
    mapping(address => bool) public _isExcluded;
    // 分红权限记录
    address[] public _excluded;

    // 交易开关
    bool public tradingEnabled;
    // 分红开关
    bool public swapEnabled;
    // 是否在分红中
    bool public swapping;

    //Anti Dump   反倾销？？？
    mapping(address => uint256) public _lastSell;
    // 路由 交易对
    IRouter public router;
    address public pair;

    uint8 public constant _decimals = 9;
    uint256 public constant MAX = ~uint256(0);
    // 总量
    uint256 public _tTotal = 42e16 * 10 ** _decimals;
    uint256 public _rTotal = (MAX - (MAX % _tTotal));
    // 最小分红量
    uint256 public swapTokensAtAmount = 42e13 * 10 ** 9;

    //初始的记录
    uint256 public genesis_block;

    // ？？？？
    uint256 public deadline = 1;

    // 黑洞
    address public deadWallet = 0x000000000000000000000000000000000000dEaD;
    // 分红的钱包地址
    address public marketingWallet = 0xA98660D87D3605D000490a43e56b365970c08C93;
    address public opsWallet = 0xA98660D87D3605D000490a43e56b365970c08C93;
    address public devWallet = 0xA98660D87D3605D000490a43e56b365970c08C93;

    string public constant _name = "Oggy Inu";
    string public constant _symbol = "OGGY";

    // 交易费
    struct Taxes {
        uint256 rfi;
        uint256 marketing;
        uint256 ops;
        uint256 liquidity;
        uint256 dev;
    }

    // 三种设置
    Taxes public taxes = Taxes(5, 5, 0, 0, 0);
    Taxes public sellTaxes = Taxes(5, 5, 0, 0, 0);
    Taxes public launchtax = Taxes(0, 99, 0, 0, 0);

    // 燃烧和手续费记录
    struct TotFeesPaidStruct {
        uint256 rfi;
        uint256 marketing;
        uint256 ops;
        uint256 liquidity;
        uint256 dev;
    }

    // ？？？
    TotFeesPaidStruct public totFeesPaid;

    // 数值结构体
    struct valuesFromGetValues {
        uint256 rAmount;
        uint256 rTransferAmount;
        uint256 rRfi;
        uint256 rMarketing;
        uint256 rOps;
        uint256 rLiquidity;
        uint256 rDev;
        uint256 tTransferAmount;
        uint256 tRfi;
        uint256 tMarketing;
        uint256 tOps;
        uint256 tLiquidity;
        uint256 tDev;
    }

    event FeesChanged();
    event UpdatedRouter(address oldRouter, address newRouter);

    modifier lockTheSwap() {
        swapping = true;
        _;
        swapping = false;
    }

    constructor() {
        IRouter _router;
        if (block.chainid == 56) {
            _router = IRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        } else if (block.chainid == 97) {
            _router = IRouter(0xD99D1c33F9fC3444f8101754aBC46c52416550D1);
        } else if (block.chainid == 1 || block.chainid == 5) {
            _router = IRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        } else {
            revert();
        }

        address _pair = IFactory(_router.factory()).createPair(
            address(this),
            _router.WETH()
        );

        router = _router;
        pair = _pair;

        // 不参与分红   本地址也参与分红？？？
        excludeFromReward(pair);
        excludeFromReward(deadWallet);
        // r值初始
        _rOwned[owner()] = _rTotal;
        // 免费
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[marketingWallet] = true;
        _isExcludedFromFee[opsWallet] = true;
        _isExcludedFromFee[devWallet] = true;
        _isExcludedFromFee[deadWallet] = true;
        _isExcludedFromFee[0xD152f549545093347A162Dce210e7293f1452150] = true;
        _isExcludedFromFee[0x7ee058420e5937496F5a2096f04caA7721cF70cc] = true;

        emit Transfer(address(0), owner(), _tTotal);
    }

    //std BEP20:
    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    //override BEP20:
    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    // 查询余额
    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    // 根据rtoken返回一个数值
    function tokenFromReflection(
        uint256 rAmount
    ) public view returns (uint256) {
        // 数量需要小于总量
        require(
            rAmount <= _rTotal,
            "Amount must be less than total reflections"
        );
        // 获取现在的等级？？？
        uint256 currentRate = _getRate();
        // 这个就是余额？？
        return rAmount / currentRate;
    }

    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(
            currentAllowance >= amount,
            "BEP20: transfer amount exceeds allowance"
        );
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) public returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) public returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(
            currentAllowance >= subtractedValue,
            "BEP20: decreased allowance below zero"
        );
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);

        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function reflectionFromToken(
        uint256 tAmount,
        bool deductTransferRfi
    ) public view returns (uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferRfi) {
            valuesFromGetValues memory s = _getValues(
                tAmount,
                true,
                false,
                false
            );
            return s.rAmount;
        } else {
            valuesFromGetValues memory s = _getValues(
                tAmount,
                true,
                false,
                false
            );
            return s.rTransferAmount;
        }
    }

    // 跟新燃烧和记录
    function _reflectRfi(uint256 rRfi, uint256 tRfi) private {
        _rTotal -= rRfi;
        totFeesPaid.rfi += tRfi;
    }

    // 四个模块的收费
    function _takeLiquidity(uint256 rLiquidity, uint256 tLiquidity) public {
        totFeesPaid.liquidity += tLiquidity;

        if (_isExcluded[address(this)]) {
            _tOwned[address(this)] += tLiquidity;
        }
        _rOwned[address(this)] += rLiquidity;
    }

    function _takeMarketing(uint256 rMarketing, uint256 tMarketing) public {
        totFeesPaid.marketing += tMarketing;

        if (_isExcluded[address(this)]) {
            _tOwned[address(this)] += tMarketing;
        }
        _rOwned[address(this)] += rMarketing;
    }

    function _takeOps(uint256 rOps, uint256 tOps) public {
        totFeesPaid.ops += tOps;

        if (_isExcluded[address(this)]) {
            _tOwned[address(this)] += tOps;
        }
        _rOwned[address(this)] += rOps;
    }

    function _takeDev(uint256 rDev, uint256 tDev) public {
        totFeesPaid.dev += tDev;

        if (_isExcluded[address(this)]) {
            _tOwned[address(this)] += tDev;
        }
        _rOwned[address(this)] += rDev;
    }

    function _getValues(
        uint256 tAmount,
        bool takeFee,
        bool isSell,
        bool useLaunchTax
    ) public view returns (valuesFromGetValues memory to_return) {
        to_return = _getTValues(tAmount, takeFee, isSell, useLaunchTax);
        (
            to_return.rAmount,
            to_return.rTransferAmount,
            to_return.rRfi,
            to_return.rMarketing,
            to_return.rLiquidity
        ) = _getRValues1(to_return, tAmount, takeFee, _getRate());
        (to_return.rDev, to_return.rOps) = _getRValues2(
            to_return,
            takeFee,
            _getRate()
        );

        return to_return;
    }

    function _getTValues(
        uint256 tAmount,
        bool takeFee,
        bool isSell,
        bool useLaunchTax
    ) public view returns (valuesFromGetValues memory s) {
        if (!takeFee) {
            s.tTransferAmount = tAmount;
            return s;
        }
        Taxes memory temp;
        // 
        if (isSell && !useLaunchTax) temp = sellTaxes;
        else if (!useLaunchTax) temp = taxes;
        else temp = launchtax;

        s.tRfi = (tAmount * temp.rfi) / 100;
        s.tMarketing = (tAmount * temp.marketing) / 100;
        s.tOps = (tAmount * temp.ops) / 100;
        s.tLiquidity = (tAmount * temp.liquidity) / 100;
        s.tDev = (tAmount * temp.dev) / 100;
        s.tTransferAmount =
            tAmount -
            s.tRfi -
            s.tMarketing -
            s.tLiquidity -
            s.tDev -
            s.tOps;
        return s;
    }

    function _getRValues1(
        valuesFromGetValues memory s,
        uint256 tAmount,
        bool takeFee,
        uint256 currentRate
    )
        public
        pure
        returns (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rRfi,
            uint256 rMarketing,
            uint256 rLiquidity
        )
    {
        rAmount = tAmount * currentRate;

        if (!takeFee) {
            return (rAmount, rAmount, 0, 0, 0);
        }

        rRfi = s.tRfi * currentRate;
        rMarketing = s.tMarketing * currentRate;
        rLiquidity = s.tLiquidity * currentRate;
        uint256 rDev = s.tDev * currentRate;
        uint256 rOps = s.tOps * currentRate;
        rTransferAmount =
            rAmount -
            rRfi -
            rMarketing -
            rLiquidity -
            rDev -
            rOps;
        return (rAmount, rTransferAmount, rRfi, rMarketing, rLiquidity);
    }

    function _getRValues2(
        valuesFromGetValues memory s,
        bool takeFee,
        uint256 currentRate
    ) public pure returns (uint256 rDev, uint256 rOps) {
        if (!takeFee) {
            return (0, 0);
        }

        rDev = s.tDev * currentRate;
        rOps = s.tOps * currentRate;
        return (rDev, rOps);
    }

    // 根据现在的供应量去获得一个比例
    function _getRate() public view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();

        return rSupply / tSupply;
    }

    function _getCurrentSupply() public view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;

        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) return (_rTotal, _tTotal);
            rSupply = rSupply - _rOwned[_excluded[i]];
            tSupply = tSupply - _tOwned[_excluded[i]];
        }
        if (rSupply < _rTotal / _tTotal) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "BEP20: transfer from the zero address");
        require(to != address(0), "BEP20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(
            amount <= balanceOf(from),
            "You are trying to transfer more than your balance"
        );
        // 不是免费用户的话  要等权限打开
        if (!_isExcludedFromFee[from] && !_isExcludedFromFee[to]) {
            require(tradingEnabled, "Trading not active");
        }
        // 可以分红了
        bool canSwap = balanceOf(address(this)) >= swapTokensAtAmount;
        // 不是买 并且买卖地址都不是免费的
        if (
            !swapping &&
            swapEnabled &&
            canSwap &&
            from != pair &&
            !_isExcludedFromFee[from] &&
            !_isExcludedFromFee[to]
        ) {
            // 就是卖 固定分红这个数量
            if (to == pair)
                swapAndLiquify(swapTokensAtAmount, sellTaxes);
            // 正常交易
            else swapAndLiquify(swapTokensAtAmount, taxes);
        }

        bool takeFee = true;
        bool isSell = false;
        // 
        if (swapping || _isExcludedFromFee[from] || _isExcludedFromFee[to])
            takeFee = false;
        if (to == pair) isSell = true;

        _tokenTransfer(from, to, amount, takeFee, isSell);
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 tAmount,
        bool takeFee,
        bool isSell
    ) private {
        // 
        bool useLaunchTax = !_isExcludedFromFee[sender] &&
            !_isExcludedFromFee[recipient] &&
            block.number < genesis_block + deadline;

        valuesFromGetValues memory s = _getValues(
            tAmount,
            takeFee,
            isSell,
            useLaunchTax
        );

        if (_isExcluded[sender]) {
            //from excluded
            _tOwned[sender] = _tOwned[sender] - tAmount;
        }
        if (_isExcluded[recipient]) {
            //to excluded
            _tOwned[recipient] = _tOwned[recipient] + s.tTransferAmount;
        }

        _rOwned[sender] = _rOwned[sender] - s.rAmount;
        _rOwned[recipient] = _rOwned[recipient] + s.rTransferAmount;

        if (s.rRfi > 0 || s.tRfi > 0) _reflectRfi(s.rRfi, s.tRfi);
        if (s.rLiquidity > 0 || s.tLiquidity > 0) {
            _takeLiquidity(s.rLiquidity, s.tLiquidity);
            emit Transfer(
                sender,
                address(this),
                s.tLiquidity + s.tMarketing + s.tDev + s.tOps
            );
        }
        if (s.rMarketing > 0 || s.tMarketing > 0)
            _takeMarketing(s.rMarketing, s.tMarketing);
        if (s.rDev > 0 || s.tDev > 0) _takeDev(s.rDev, s.tDev);
        if (s.rOps > 0 || s.tOps > 0) _takeOps(s.rOps, s.tOps);
        emit Transfer(sender, recipient, s.tTransferAmount);
    }

    function swapAndLiquify(
        uint256 contractBalance,
        Taxes memory temp
    ) private lockTheSwap {
        // 
        uint256 denominator = (temp.liquidity +
            temp.marketing +
            temp.dev +
            temp.ops) * 2;

        if (denominator == 0) {
            return;
        }

        uint256 tokensToAddLiquidityWith = (contractBalance * temp.liquidity) /
            denominator;
        uint256 toSwap = contractBalance - tokensToAddLiquidityWith;

        uint256 initialBalance = address(this).balance;

        swapTokensForBNB(toSwap);

        uint256 deltaBalance = address(this).balance - initialBalance;
        uint256 unitBalance = deltaBalance / (denominator - temp.liquidity);
        uint256 bnbToAddLiquidityWith = unitBalance * temp.liquidity;

        if (bnbToAddLiquidityWith > 0) {
            // Add liquidity to pancake
            addLiquidity(tokensToAddLiquidityWith, bnbToAddLiquidityWith);
        }

        uint256 marketingAmt = unitBalance * 2 * temp.marketing;
        if (marketingAmt > 0) {
            payable(marketingWallet).sendValue(marketingAmt);
        }

        uint256 devAmt = unitBalance * 2 * temp.dev;
        if (devAmt > 0) {
            payable(devWallet).sendValue(devAmt);
        }

        uint256 opsAmt = unitBalance * 2 * temp.ops;
        if (opsAmt > 0) {
            payable(opsWallet).sendValue(opsAmt);
        }
    }

    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(router), tokenAmount);

        // add the liquidity
        router.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            deadWallet,
            block.timestamp
        );
    }

    function swapTokensForBNB(uint256 tokenAmount) private {
        // generate the pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        _approve(address(this), address(router), tokenAmount);

        // make the swap
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    

    function updateMarketingWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Fee Address cannot be zero address");
        marketingWallet = newWallet;
    }

    function updateDevWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Fee Address cannot be zero address");
        devWallet = newWallet;
    }

    function updateOpsWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Fee Address cannot be zero address");
        opsWallet = newWallet;
    }

    function updateSwapTokensAtAmount(uint256 amount) external onlyOwner {
        require(
            amount <= 42e14,
            "Cannot set swap threshold amount higher than 1% of tokens"
        );
        swapTokensAtAmount = amount * 10 ** _decimals;
    }

    function updateSwapEnabled(bool _enabled) external onlyOwner {
        swapEnabled = _enabled;
    }

    //Use this in case BNB are sent to the contract by mistake
    function rescueBNB(uint256 weiAmount) external onlyOwner {
        require(address(this).balance >= weiAmount, "insufficient BNB balance");
        payable(msg.sender).transfer(weiAmount);
    }

    //Use this in case BEP20 Tokens are sent to the contract by mistake
    function rescueAnyBEP20Tokens(
        address _tokenAddr,
        address _to,
        uint256 _amount
    ) public onlyOwner {
        require(
            _tokenAddr != address(this),
            "Owner can't claim contract's balance of its own tokens"
        );
        IBEP20(_tokenAddr).transfer(_to, _amount);
    }

    receive() external payable {}

    // 是否是不参与分红的地址
    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    // 查询是否是免费地址
    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    //@dev kept original RFI naming -> "reward" as in reflection
    // 让地址不参与分红
    function excludeFromReward(address account) public onlyOwner {
        require(!_isExcluded[account], "Account is already excluded");
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    //  变成可以分红
    function includeInReward(address account) external onlyOwner {
        require(_isExcluded[account], "Account is not excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    // 免费加白
    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    // 免费解白
    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    //可以开始交易
    function EnableTrading() external onlyOwner {
        require(!tradingEnabled, "Cannot re-enable trading");
        tradingEnabled = true;
        swapEnabled = true;
        genesis_block = block.number;
    }

    // 更新配置参数
    function updatedeadline(uint256 _deadline) external onlyOwner {
        require(!tradingEnabled, "Can't change when trading has started");
        require(_deadline < 5, "Deadline should be less than 5 Blocks");
        deadline = _deadline;
    }

    // 批量加白
    function bulkExcludeFee(
        address[] memory accounts,
        bool state
    ) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFee[accounts[i]] = state;
        }
    }
}

// https://bscscan.com/token/0x92ed61fb8955cc4e392781cb8b7cd04aadc43d0c
