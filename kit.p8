pico-8 cartridge // http://www.pico-8.com
version 19
__lua__
-- omercan balandi
-- github.com/obsfx
-- gamedev utils
--		quadtree
-- 	collision detection
-- 	collision resolution
-- 	debug drawing
-- 	util functions
-->8
--util
function dr(x,y,w,h,c)
	rectfill(x,y,x+w-1,y+h-1,c)
end

function merge_t(t1,t2)
	for k,v in pairs(t2) do 
		t1[k] = v 
	end
	
	return t1
end

function merge_arr(a,b)
	for bv in all(b) do
		add(a, bv)
	end
	
	return a
end
-->8
--objects
function rectangle(x,y,w,h)
	return {
		x=x,
		y=y,
		w=w,
		h=h,
		
		--get left
		get_l=function(self)
			return self.x
		end,
		
		--get right
		get_r=function(self)
			return self.x+self.w
		end,
		
		--get top
		get_t=function(self)
			return self.y
		end,
		
		--get bottom
		get_b=function(self)
			return self.y+self.h
		end,
		
		--half width
		get_hw=function(self)
			return self.w*0.5
		end,
	
		--half height
		get_hh=function(self)
			return self.h*0.5
		end,
		
		--midx
		get_mx=function(self)
			return self.x+self:get_hw()
		end,
		
		--midy
		get_my=function(self)
			return self.y+self:get_hh()
		end
	}
end

function obj(x,y,w,h,de)
	local t={
		de=de or false,
		col=de or false,
		ovlp=de or false,
		cea=rectangle(0,0,w*4,h*4),
	
		updatecea=function(self)			
			self.cea.x=self.x-(self.w*2-self.w/2)
			self.cea.y=self.y-(self.h*2-self.h/2)
		end
	}
	
	return merge_t(t,rectangle(x,y,w,h))
end
-->8
--collision
col={
	colres=function(self,x,y)
		return {
			x=x,
			y=y,
			
			l=false,
			r=false,
			t=false,
			b=false
		}	
	end,
	
	get_deltas=function(self,a,b)
		local midx1=a:get_mx()
		local midy1=a:get_my()
		
		local midx2=b:get_mx()
		local midy2=b:get_my()
		
		local dx=(midx1-midx2)/a:get_hw()
		local dy=(midy1-midy2)/a:get_hh()
		
		local abs_dx=abs(dx)
		local abs_dy=abs(dy)
		local abs_dxy=abs(abs_dx-abs_dy)
		
		return {
			dx=dx,
			dy=dy,
			abs_dx=abs_dx,
			abs_dy=abs_dy,
			abs_dxy=abs_dxy
		}
	end,
	
	check=function(self,a,b,incb)
			local l1=a:get_l()
			local r1=a:get_r()
			local t1=a:get_t()
			local b1=a:get_b()
			
			local l2=b:get_l()
			local r2=b:get_r()
			local t2=b:get_t()
			local b2=b:get_b()
			
			local midx1=a:get_mx()
			local midy1=a:get_my()
			
			local midx2=b:get_mx()
			local midy2=b:get_my()
			
			local cond=r1<l2 or l1>r2 or b1<t2 or t1>b2
			
			if incb then 
				cond=r1<=l2 or l1>=r2 or b1<=t2 or t1>=b2	
			end
			
			return not cond
	end,
	
	resolve=function(self,a,b)
		local res=self:colres(a.x,a.y)

		local deltas=self:get_deltas(a,b)
		
		local dx=deltas.dx
		local dy=deltas.dy
		local abs_dx=deltas.abs_dx
		local abs_dy=deltas.abs_dy
		local abs_dxy=deltas.abs_dxy
		
		a.x=b.x-a.w
		a.y=b.y-a.h
		
		ref_deltas=self:get_deltas(a,b)
		
		ref_abs_dx=ref_deltas.abs_dx
		ref_abs_dy=ref_deltas.abs_dy
		ref_abs_dxy=ref_deltas.abs_dxy
		
		norm_abs_dx=abs(abs_dx-ref_abs_dx)
		norm_abs_dy=abs(abs_dy-ref_abs_dy)
		norm_abs_dxy=abs(abs_dxy+ref_abs_dxy)
		
		if norm_abs_dxy<0.1 then
			if dx<0 then res.x=b.x-a.w
			else res.x=b.x+b.w end
			
			if dy<0 then res.y=b.y-a.h
			else res.y=b.y+b.h end
		elseif norm_abs_dx<norm_abs_dy then
			if dx<0 then
				res.x=b.x-a.w
				res.r=true
			else
				res.x=b.x+b.w
				res.l=true
			end
		else
			if dy<0 then
				res.y=b.y-a.h
				res.b=true
			else
				res.y=b.y+b.h
				res.t=true
			end
		end
		
		return res
	end
}
-->8
--qtree
function qtree(x,y,w,h,cap)
	local t={
		cap=cap,
		col=col,
		
		tl=nil,
		tr=nil,
		bl=nil,
		br=nil,
		
		divided=false,
		items={},
		
		subdivide=function(self)
			local bx=self.x
			local by=self.y
			local bhw=self.w*0.5
			local bhh=self.h*0.5
			
			self.tl=qtree(bx,by,bhw,bhh,self.cap)
			self.tr=qtree(bx+bhw,by,bhw,bhh,self.cap)
			self.bl=qtree(bx,by+bhh,bhw,bhh,self.cap)
			self.br=qtree(bx+bhw,by+bhh,bhw,bhh,self.cap)
			
			self.divided=true
		end,
		
		insert=function(self,obj)
			if not col:check(self,obj,true) then
				return false				
			end
			
			if #self.items<self.cap then
				add(self.items,obj)
				return true
			else
				if not self.divided then
					self:subdivide()
				end
				
				if self.tl:insert(obj) then
					return true
				elseif self.tr:insert(obj) then
					return true
				elseif self.bl:insert(obj) then
					return true
				elseif self.br:insert(obj) then
					return true
				end
			end
		end,
		
		query=function(self,area)
			local items={}
			
			if not col:check(self,area,false) then
				return items				
			end
			
			for item in all(self.items) do
				if col:check(item,area,true) then
					add(items,item)
				end
			end
			
			if self.divided then
				items=merge_arr(items,self.tl:query(area))
				items=merge_arr(items,self.tr:query(area))
				items=merge_arr(items,self.bl:query(area))
				items=merge_arr(items,self.br:query(area))
			end
			
			return items
		end,
		
		getc=function(self) 
			local c={}
			
			add(c,self)
			
			if self.divided then
				c=merge_arr(c,self.tl:getc())
				c=merge_arr(c,self.tr:getc())
				c=merge_arr(c,self.bl:getc())
				c=merge_arr(c,self.br:getc())
			end
			
			return c
		end,
		
		gete=function(self)
			local e={}
			
			e=merge_arr(e,self.items)
			
			if self.divided then
				e=merge_arr(e,self.tl:gete())
				e=merge_arr(e,self.tr:gete())
				e=merge_arr(e,self.bl:gete())
				e=merge_arr(e,self.br:gete())
			end
			
			return e
		end
	}
	
	return merge_t(t,rectangle(x,y,w,h,c))
end
-->8
--debug util
function d_rb(items,c)
	for i in all(items) do
		rect(i.x,i.y,i.x+i.w-1,i.y+i.h-1)
	end
end

function d_rc(items,c)
	for i in all(items) do
		if i.de then
			rect(i.cea.x,i.cea.y,i.cea.x+i.cea.w-1,i.cea.y+i.cea.h-1,c)
		end		
	end
end
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
