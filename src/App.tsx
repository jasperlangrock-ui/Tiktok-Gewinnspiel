import {Routes,Route,Navigate} from 'react-router-dom';
import {PublicPage} from './pages/PublicPage'; import {AdminPage} from './pages/AdminPage'; import {LoginPage} from './pages/LoginPage';
export default function App(){return <Routes><Route path="/" element={<PublicPage/>}/><Route path="/login" element={<LoginPage/>}/><Route path="/admin" element={<AdminPage/>}/><Route path="*" element={<Navigate to="/" replace/>}/></Routes>}
