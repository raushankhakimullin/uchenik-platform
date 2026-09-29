'use client';
import { useEffect, useState, type FormEvent } from 'react';
import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import { ArrowRight } from 'lucide-react';
import { db } from '@/lib/supabase';
import { errorText } from '@/lib/use-data';
import { useAuth } from './core';
export function AuthPage(){
  const router=useRouter();const search=useSearchParams()??new URLSearchParams();const {user}=useAuth();
  const [mode,setMode]=useState<'login'|'signup'|'reset'>('login');const [name,setName]=useState('');const [email,setEmail]=useState('');const [password,setPassword]=useState('');const [busy,setBusy]=useState(false);const [error,setError]=useState('');const [message,setMessage]=useState('');
  const next=search.get('next')?.startsWith('/')&&!search.get('next')?.startsWith('//')?search.get('next')!:'/dashboard';
  useEffect(()=>{if(user&&search.get('reset')!=='1')router.replace(next)},[user,router,next,search]);
  if(user&&search.get('reset')!=='1')return null;
  async function submit(e:FormEvent){e.preventDefault();setError('');setMessage('');setBusy(true);
    try{
      if(mode==='reset'){const {error}=await db().auth.resetPasswordForEmail(email,{redirectTo:window.location.origin+'/auth?reset=1'});if(error)throw error;setMessage('Письмо со ссылкой для восстановления отправлено. Проверьте почту.');}
      else if(search.get('reset')==='1'&&mode==='login'){const {error}=await db().auth.updateUser({password});if(error)throw error;setMessage('Пароль обновлён. Теперь вы можете войти.');}
      else if(mode==='signup'){const {data,error}=await db().auth.signUp({email,password,options:{data:{display_name:name}}});if(error)throw error;if(data.session)router.push(next);else setMessage('Проверьте почту: мы отправили ссылку для подтверждения регистрации.');}
      else {const {error}=await db().auth.signInWithPassword({email,password});if(error)throw error;router.push(next)}
    }catch(e){setError(errorText(e))}finally{setBusy(false)}
  }
  return <div className="auth-screen"><div className="auth-art"><Link href="/" className="brand"><span className="brand-mark">S</span> SONS OF GOD</Link><div><span className="eyebrow goldtext">ШКОЛА УЧЕНИЧЕСТВА</span><h1>Путь начинается с ответа.</h1><p>Слышать Слово. Делать шаг. Помогать другому следовать за Иисусом.</p></div><span className="eyebrow">НЕ ПРИХОЖАНИН. УЧЕНИК.</span></div><div className="auth-content"><div className="auth-box"><span className="eyebrow" style={{color:'#977b42'}}>ДОБРО ПОЖАЛОВАТЬ</span><h2>{search.get('reset')==='1'?'Новый пароль':mode==='reset'?'Вернуться к пути':mode==='signup'?'Начнём вместе':'Продолжить путь'}</h2><p>{mode==='signup'?'Создайте аккаунт, чтобы сохранять решения и расти вместе с другими.':'Войдите, чтобы вернуться к своим урокам, людям и следующему шагу.'}</p>{search.get('reset')!=='1'&&<div className="auth-tabs"><button className={mode==='login'?'selected':''} onClick={()=>{setMode('login');setError('');setMessage('')}}>Войти</button><button className={mode==='signup'?'selected':''} onClick={()=>{setMode('signup');setError('');setMessage('')}}>Регистрация</button></div>}
  <form onSubmit={submit}>{mode==='signup'&&<div className="formrow"><label><span className="label">Ваше имя</span><input className="field" value={name} onChange={e=>setName(e.target.value)} required placeholder="Как к вам обращаться"/></label></div>}{search.get('reset')!=='1'&&<div className="formrow"><label><span className="label">Электронная почта</span><input className="field" type="email" value={email} onChange={e=>setEmail(e.target.value)} required placeholder="you@example.com"/></label></div>}{mode!=='reset'&&<div className="formrow"><label><span className="label">{search.get('reset')==='1'?'Новый пароль':'Пароль'}</span><input className="field" type="password" minLength={6} value={password} onChange={e=>setPassword(e.target.value)} required placeholder="Не менее 6 символов"/></label></div>}
  {error&&<div className="error" role="alert">{error}</div>}{message&&<div className="success" role="status">{message}</div>}<button className="btn" style={{width:'100%'}} disabled={busy}>{busy?'Подождите…':mode==='reset'?'Отправить письмо':mode==='signup'?'Создать аккаунт':search.get('reset')==='1'?'Сохранить пароль':'Войти'} <ArrowRight size={16}/></button></form>
  <div style={{marginTop:23,textAlign:'center'}}><button className="link-button" onClick={()=>{setMode(mode==='reset'?'login':'reset');setError('');setMessage('')}}>{mode==='reset'?'Вернуться ко входу':'Забыли пароль?'}</button></div></div></div></div>
}