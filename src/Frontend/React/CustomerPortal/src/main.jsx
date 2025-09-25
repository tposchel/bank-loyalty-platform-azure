import React from 'react'
import { createRoot } from 'react-dom/client'
import { PublicClientApplication } from '@azure/msal-browser'
import { MsalProvider, AuthenticatedTemplate, UnauthenticatedTemplate, useMsal } from '@azure/msal-react'
import { msalConfig, apiConfig } from './msalConfig'

const pca = new PublicClientApplication(msalConfig)
function Home() {
  const { instance, accounts } = useMsal()
  const login = () => instance.loginRedirect({ scopes: apiConfig.scopes })
  const logout = () => instance.logoutRedirect()
  async function callApi() {
    const account = accounts[0]
    const resp = await instance.acquireTokenSilent({ account, scopes: apiConfig.scopes })
    const r = await fetch(`${apiConfig.apiBase}/api/customers`, { headers: { Authorization: `Bearer ${resp.accessToken}`}})
    alert(await r.text())
  }
  return (<div style={{fontFamily:'system-ui', padding:24}}>
    <h1>Customer Portal (Azure AD B2C)</h1>
    <AuthenticatedTemplate>
      <p>Signed in as {accounts[0]?.username}</p>
      <button onClick={callApi}>Call API</button>
      <button onClick={logout} style={{marginLeft:12}}>Sign out</button>
    </AuthenticatedTemplate>
    <UnauthenticatedTemplate><button onClick={login}>Sign in / Sign up</button></UnauthenticatedTemplate>
  </div>)
}
createRoot(document.getElementById('root')).render(<MsalProvider instance={pca}><Home /></MsalProvider>)
