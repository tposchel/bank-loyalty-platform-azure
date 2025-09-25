export const msalConfig = {
  auth: {
    clientId: import.meta.env.VITE_B2C_SPA_CLIENT_ID,
    authority: `https://${import.meta.env.VITE_B2C_DOMAIN}/${import.meta.env.VITE_B2C_SIGNIN_POLICY}`,
    knownAuthorities: [import.meta.env.VITE_B2C_DOMAIN],
    redirectUri: window.location.origin
  },
  cache: { cacheLocation: "localStorage", storeAuthStateInCookie: false }
};
export const apiConfig = {
  apiBase: import.meta.env.VITE_API_BASE || "http://localhost:5000",
  scopes: [`api://${import.meta.env.VITE_B2C_API_CLIENT_ID}/Loyalty.Read`]
};
