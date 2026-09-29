'use client';
import { useCallback, useEffect, useState } from 'react';
import { db } from './supabase';
import { useAuth } from '@/components/core';
export function useTable<T=Record<string,any>>(table:string, column:string, value?:string, order?:string) {
  const {user}=useAuth(); const [data,setData]=useState<T[]>([]);const [loading,setLoading]=useState(true);const [error,setError]=useState('');
  const reload=useCallback(async()=>{
    if(!user||!value){setLoading(false);return}
    setLoading(true);setError('');
    let q:any=db().from(table).select('*').eq(column,value);
    if(order)q=q.order(order,{ascending:true});
    const result=await q;
    if(result.error)setError(result.error.message);
    else setData((result.data || []) as T[]);
    setLoading(false);
  },[table,column,value,order,user]);
  useEffect(()=>{void reload()},[reload]);
  return {data,loading,error,reload,setData};
}
export async function run(promise: PromiseLike<{data:any;error:{message:string}|null}>):Promise<any> {
  const {data,error}=await promise;if(error)throw new Error(error.message);return data;
}
export const errorText=(e:unknown)=>e instanceof Error?e.message:'Не удалось выполнить действие. Попробуйте ещё раз.';