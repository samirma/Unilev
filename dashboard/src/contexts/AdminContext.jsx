"use client";

import React, { createContext, useContext, useState, useEffect } from "react";

const AdminContext = createContext();

export function AdminProvider({ children }) {
    const [isAdmin, setIsAdmin] = useState(false);

    useEffect(() => {
        const stored = localStorage.getItem("eswap_admin_mode");
        if (stored === "true") {
            setIsAdmin(true);
        } else if (stored === null) {
            // Fallback to env var if not set in local storage
            const envValue = process.env.NEXT_PUBLIC_ADMIN_MODE;
            setIsAdmin(envValue === 'true' || envValue === '1');
        }
    }, []);

    const toggleAdminMode = () => {
        setIsAdmin((prev) => {
            const newValue = !prev;
            localStorage.setItem("eswap_admin_mode", newValue ? "true" : "false");
            return newValue;
        });
    };

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