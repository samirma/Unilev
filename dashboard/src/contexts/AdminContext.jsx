"use client";

import React, { createContext, useContext, useState, useEffect } from "react";
import { useAccount } from "wagmi";

const AdminContext = createContext();

export function AdminProvider({ children }) {
    const { address, isConnected } = useAccount();
    const [isAdmin, setIsAdmin] = useState(false);

    useEffect(() => {
        if (isConnected && address) {
            // Read admin wallets from env, comma separated
            const adminWalletsStr = process.env.NEXT_PUBLIC_ADMIN_WALLETS || "";
            const adminWallets = adminWalletsStr.split(',').map(a => a.trim().toLowerCase());
            
            // If the connected wallet is in the list, they are an admin
            setIsAdmin(adminWallets.includes(address.toLowerCase()));
        } else {
            setIsAdmin(false);
        }
    }, [address, isConnected]);

    const toggleAdminMode = () => {}; // Deprecated since we use wallet auth now

    return (
        <AdminContext.Provider value={{ isAdmin, toggleAdminMode }}>
            {children}
        </AdminContext.Provider>
    );
}

export function useAdmin() {
    const context = useContext(AdminContext);
    if (context === undefined) {
        throw new Error('useAdmin must be used within an AdminProvider');
    }
    return context;
}