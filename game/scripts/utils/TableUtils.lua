--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@class TableUtils
local TableUtils = {}

---@param t table
---@param value any
---@return any
function TableUtils.find(t, value)
    for key, _v in pairs(t) do
        if _v == value then
            return key;
        end
    end
end

---@generic V
---@param t V
---@return V
function TableUtils.copyDeep(t)
    if type(t) ~=  "table" then
        return t
    end

    local copy = {}

    local copyTable = TableUtils.copyDeep
    for k, v in pairs(t) do
        copy[k] = copyTable(v)
    end

    return copy
end

---@param dest table
---@param from table
---@return table
function TableUtils.copyTo(dest, from)
    for key, value in pairs(from) do
        dest[key] = value
    end
    return dest
end

---@param dest table
---@param from table
---@return table
function TableUtils.rawCopyTo(dest, from)
    for key, value in pairs(from) do
        rawset(dest, key, value)
    end
    return dest
end

---@param t table
function TableUtils.clean(t)
    local key = next(t)
    while key do
        t[key] = nil
        key = next(t)
    end
end

---@generic V
---@param t table<number, V>
---@return V?
function TableUtils.last(t)
    if t == nil or #t == 0 then
        return nil
    end
    return t[#t]
end

---@generic V
---@param t table<number, V>
---@return V?
function TableUtils.after(t, v)
    if t == nil then
        return nil
    end
    for i = 1, #t do
        if t[i] == v then
            return t[i + 1]
        end
    end
    return nil
end

---@generic V
---@param t V[]
---@return table<V, true>
function TableUtils.toHashmap(t)
    local o = {}
    for i = 1, #t do
        o[t[i]] = true
    end
    return o
end

---@param t table
---@param keys any[]
function TableUtils.removeKeys(t, keys)
    for i = 1, #keys do
        t[keys[i]] = nil
    end
end

---@param t table
---@param keys any[]
function TableUtils.removeKeysRaw(t, keys)
    for i = 1, #keys do
        rawset(t, keys[i], nil)
    end
end

---@param dest table
---@param src table
---@param keys any[]
function TableUtils.copyKeysDeep(dest, src, keys)
    for i = 1, #keys do
        local key = keys[i]
        local v = src[key]
        if type(v) == "table" then
            dest[key] = TableUtils.copyDeep(v)
        else
            dest[key] = v
        end
    end
end

---@param dest table
---@param src table
---@param keys any[]
function TableUtils.copyKeysDeepRaw(dest, src, keys)
    for i = 1, #keys do
        local key = keys[i]
        local v = src[key]
        if type(v) == "table" then
            rawset(dest, key, TableUtils.copyDeep(v))
        else
            rawset(dest, key, v)
        end
    end
end

---@param from table
---@param to table
---@param keys any[]
function TableUtils.moveKeys(from, to, keys)
    local key
    for i = 1, #keys do
        key = keys[i]
        to[key] = from[key]
        from[key] = nil
    end
end

---@generic FunctionName
---@param t { [FunctionName]: fun(...) }[]
---@param key FunctionName
function TableUtils.callEvery(t, key, ...)
    for i = 1, #t do
        t[i][key](...)
    end
end

---@param t { [string]: fun(...) }[]
---@param key string
function TableUtils.callEveryReverse(t, key, ...)
    for i = #t, 1, -1 do
        t[i][key](...)
    end
end

---@generic K, V
---@param t table<K, V>
---@param fun fun(value: V): boolean
---@return table<K, V>
function TableUtils.filter(t, fun)
    local filtered = {}
    for k, v in pairs(t) do
        if fun(v) then
            filtered[k] = v
        end
    end
    return filtered
end

return TableUtils
