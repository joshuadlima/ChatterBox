import os
from pathlib import Path

class LuaScriptLoader:
    """Utility to load and cache Lua scripts"""
    
    _cache = {}
    _script_dir = Path(__file__).parent
    
    @classmethod
    def load(cls, script_name):
        """Load a Lua script from file"""
        if script_name in cls._cache:
            return cls._cache[script_name]
        
        script_path = cls._script_dir / f"{script_name}.lua"
        
        if not script_path.exists():
            raise FileNotFoundError(f"Lua script not found: {script_path}")
        
        with open(script_path, 'r', encoding='utf-8') as f:
            script_content = f.read()
        
        cls._cache[script_name] = script_content
        return script_content
    
    @classmethod
    def clear_cache(cls):
        """Clear the script cache (useful for development)"""
        cls._cache.clear()