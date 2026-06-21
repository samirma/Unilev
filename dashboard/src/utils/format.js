/**
 * Formats a token balance or amount string dynamically based on the token's symbol
 * and size of the balance, ensuring tiny balances are visible rather than rounded to 0.
 * 
 * @param {string|number} value The raw number or string representation of the balance.
 * @param {string} symbol The token symbol (e.g. 'WBTC', 'USDC', 'WETH', 'POL').
 * @returns {string} The formatted balance string.
 */
export function formatTokenAmount(value, symbol = "") {
    if (value === undefined || value === null || value === "") return "...";
    const num = parseFloat(value);
    if (isNaN(num)) return "0.0";
    if (num === 0) return "0.0";

    const sym = symbol.toUpperCase();
    let decimals = 4; // default decimal places for formatting

    if (sym === "WBTC") {
        decimals = 8;
    } else if (sym === "WETH" || sym === "ETH") {
        decimals = 6;
    } else if (sym === "USDC" || sym === "DAI") {
        decimals = 2;
    } else if (sym === "WPOL" || sym === "POL") {
        decimals = 4;
    }

    // If the number is non-zero and smaller than 1, calculate needed decimals
    // to display at least 2 significant digits (capped at 8 decimals)
    if (num > 0 && num < 1) {
        let temp = num;
        let leadingZeroes = 0;
        while (temp < 1 && leadingZeroes < 8) {
            temp *= 10;
            leadingZeroes++;
        }
        // Show at least 2 significant digits after leading zeroes
        const requiredDecimals = leadingZeroes + 1;
        decimals = Math.max(decimals, Math.min(requiredDecimals, 8));
    }

    let formatted = num.toFixed(decimals);

    // Trim trailing zeroes after the decimal point, but keep at least 2 decimals
    // (e.g., "1.230000" -> "1.23", "1.200000" -> "1.20")
    if (formatted.includes(".")) {
        while (formatted.endsWith("0") && formatted.split(".")[1].length > 2) {
            formatted = formatted.slice(0, -1);
        }
    }

    return formatted;
}
