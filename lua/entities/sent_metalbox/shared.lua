AddCSLuaFile("shared.lua")

ENT.Type             = "anim"
ENT.Base             = "base_anim"
ENT.PrintName         = "Metal Box"
ENT.Author             = "MacDGuy"
ENT.Information        = "Metal Box from Mario.  Turns you into metal mario for 25 seconds!"
ENT.Category        = "Toybox Classics"
 
ENT.Spawnable        = true
ENT.AdminOnly    = false

if SERVER then

    function ENT:SpawnFunction( ply, tr )

        if !tr.Hit then return end
    
        local SpawnPos = tr.HitPos + tr.HitNormal * 16
        local ent = ents.Create( ClassName )
        ent:SetPos( SpawnPos + Vector( 0, 0, 4 ) )
        ent:Spawn()
        ent:Activate()

        return ent

    end

    function ENT:Initialize()

        self:SetModel( "models/nostalgia/mario/metalbox.mdl" )

        self:PhysicsInit( SOLID_VPHYSICS )
        self:SetMoveType( MOVETYPE_VPHYSICS )
        self:SetSolid( SOLID_VPHYSICS )

        self:DrawShadow( true )
        self:StartMotionController()
        self:SetPos( self:GetPos() + Vector( 0, 0, 74 ) )

        local phys = self:GetPhysicsObject()
        if IsValid( phys ) then
            phys:Wake()
        end

    end
    
    function ENT:Think()

        local tr = util.TraceLine( {
            start = self:GetPos(),
            endpos = self:GetPos() + Vector( 0, 0, -10000 ),
            filter = self,
            mask = MASK_SOLID_BRUSHONLY    
        } )

        self.ZPos = tr.HitPos.z + 94
        self:NextThink( CurTime() + .5 )
        
    end

    function ENT:PhysicsCollide( data, phys )

        if self.IsCrushed then return end

        local ply = data.HitEntity
        if !IsValid( ply ) || !ply:IsPlayer() || ply.IsMetalMario then return end

        local norm = data.HitNormal
        local dot = ( self:GetUp() * -1 ):Dot( data.HitNormal )
        if math.abs( dot ) < 0.5 then return end

        ply:MetalMario( true )
        self:Crush()

    end

    function ENT:PhysicsSimulate( phys, deltatime )

        phys:Wake()
        
        if !self.ZPos then return end
    
        local Pos = phys:GetPos()
        local Vel = phys:GetVelocity()
        local Distance = self.ZPos - Pos.z
        local AirResistance = 2
    
        if Distance == 0 then return end
    
        local Exponent = Distance^2
    
        if Distance < 0 then
            Exponent = Exponent * -1
        end
    
        Exponent = Exponent * deltatime * 300
        local zVel = Vel.z
    
        Exponent = Exponent - ( zVel * deltatime * 320 )
        Exponent = math.Clamp( Exponent, -5000, 5000 )

        local Linear = Vector( 0, 0, 0 )
        local Angular = self:UpRight( phys, deltatime ) //try to keep it upright
    
        Linear.z = Exponent
        Linear.y = Vel.y * -1 * AirResistance
        Linear.x = Vel.x * -1 * AirResistance

        return Angular, Linear, SIM_GLOBAL_ACCELERATION
    
    end
    
    function ENT:UpRight( phys, deltatime )

        if !self:NeedsUpRight() then return Vector( 0, 0, 0 ) end

        local Angles = self:GetAngles()
        Angles:RotateAroundAxis( Vector( 0, 0, 1 ), -Angles.y )

        local AngleFriction = phys:GetAngleVelocity() * -0.1

        local Cross = Angles:Up():Cross( Vector( 0, 0, 1 ) )
        local KeepUprightX, KeepUprightY = 0, 0
        KeepUprightX = Cross.x * 380
        KeepUprightY = Cross.y * 380
        
        self:Settle() // calm down lit' fella

        return ( AngleFriction + Vector( KeepUprightX, KeepUprightY, self.ZPos ) ) * deltatime * 1000

    end
    
    function ENT:NeedsUpRight()
        return self:GetUp().z < 0.95
    end
    
    //holy shit this is the dumbest fucking shit ever someone tell me how to do this better for fucksake
    function ENT:Settle()
    
        if self.Settled then return end

        self.Settled = true

        if !IsValid( self ) then return end

        local phys = self:GetPhysicsObject()
        if IsValid( phys ) then
            phys:EnableMotion( false )
        end

        timer.Simple( .5, function()

            if !IsValid( self ) then return end
            
            self.Settled = false

            local phys = self:GetPhysicsObject()
            if IsValid( phys ) then
                phys:EnableMotion( true )
            end

        end )
    
    end

    function ENT:Crush()

        self.IsCrushed = true

        umsg.Start( "BoxCrush" )
            umsg.Entity( self )
        umsg.End()
        
        timer.Simple( .25, function()

            if !IsValid( self ) then return end

            local stars = EffectData()
                stars:SetOrigin( self:GetPos() )
            util.Effect( "metalbox_stars", stars )
            
            self:Remove()

        end )
    
    end

    hook.Add( "Think", "MetalMarioThink", function()
    
        for _,ply in ipairs( player.GetAll() ) do
        
            if !ply.IsMetalMario then return end

            if ply.MetalTimer && ply.MetalTimer < CurTime() then
                ply:MetalMario( false ) //Time's up!
                return
            end

            ply:MetalMarioThink()

            local forcedown = 35
            if !ply:IsOnGround() then forcedown = 15 end
            if ply:WaterLevel() > 0 then forcedown = 64 end

            ply:SetVelocity( Vector( 0, 0, -forcedown ) )

        end
        
    end )
    hook.Add( "EntityTakeDamage", "MetalMarioProtect", function( ply, dmginfo, inflictor, attacker, amount )
        if !ply.IsMetalMario || !ply:IsPlayer() then return end
        
        if dmginfo:IsFallDamage() then
            dmginfo:ScaleDamage( 0 )
        end
        dmginfo:ScaleDamage( 0.5 )

    end )
    hook.Add( "PlayerDeath", "MetalMarioDeath", function( ply )
        if ply.IsMetalMario then
            ply:MetalMario( false, true )
        end
    end )
    hook.Add( "PlayerFootstep", "MetalMarioFootstep", function( ply, pos, foot, sound, volume, players )
        if ply.IsMetalMario then
            return true
        end
    end )

    local meta = FindMetaTable( "Player" )
    if !meta then
        Msg("ALERT! Could not hook Player Meta Table\n")
        return
    end

    function meta:MetalMario( bool, stopmusic )
    
        if bool then

            self.IsMetalMario = true
            self.MetalTimer = CurTime() + 25

            self:SetWalkSpeed( 200 )
            self:SetRunSpeed( 350 )
            self:SetJumpPower( 550 )
            self:SetMaterial( "debug/env_cubemap_model" )
            
            umsg.Start( "MetalMarioMusic", self )
                umsg.Bool( true )
            umsg.End()

        else

            self.IsMetalMario = false
            self.MetalTimer = nil
            
            self:SetWalkSpeed( 250 )
            self:SetRunSpeed( 500 )
            self:SetJumpPower( 240 )
            self:SetMaterial( "" )
            
            if stopmusic then
                umsg.Start( "MetalMarioMusic", self )
                    umsg.Bool( false )
                umsg.End()
            end

        end
    
    end

    function meta:MetalStomp()

        self:EmitSound( "physics/metal/metal_box_impact_hard" .. math.random( 1, 3 ) .. ".wav", 35, math.Rand( 30, 35 ) )
        util.ScreenShake( self:GetPos(), 5, 5, .5, 64 )

    end

    local MMLastStompPlace = {}
    function meta:MetalMarioThink()
    
        local ent = self:GetGroundEntity()
        if IsValid( ent ) then
            ent:TakeDamage( 250, self )
        end

        self.PlayStomp = self.PlayStomp or false

        if !self:IsOnGround() then

            if !self.PlayStomp then
                self.PlayStomp = true
            end

        else

            self.LastStomp = self.LastStomp or 0

            if MMLastStompPlace[ self:EntIndex() ] then

                local dist = MMLastStompPlace[ self:EntIndex() ]:Distance( self:GetPos() )
                if self:MovementKeyDown() && dist >= 3 then
                    self.PlayStomp = true
                end

            end
            MMLastStompPlace[ self:EntIndex() ] = self:GetPos()

            if self.PlayStomp && CurTime() >= self.LastStomp && self:IsMoving() then
                self.LastStomp = CurTime() + .25
                self.PlayStomp = false
                self:MetalStomp()
            end

        end

    end

    function meta:MovementKeyDown()
        return self:KeyDown( IN_FORWARD ) || self:KeyDown( IN_BACK ) || self:KeyDown( IN_MOVELEFT ) || self:KeyDown( IN_MOVERIGHT )
    end
    
    function meta:IsMoving()
        return self:GetVelocity():Length() > 0
    end

else // CLIENT

    function ENT:Draw()

        local OldPos = self:GetPos()
        self:SetPos( OldPos + self:GetAngles():Up() * math.sin( CurTime() * 2 ) * 3 )
        self:DrawModel()
        self:SetPos( OldPos )

        if self.Scale && self.Scale > 0 then

            local num, spd = 1, 8
            self.Scale = math.Approach( self.Scale, 0, ( FrameTime() * ( self.Scale * spd ) ) )
            //self:SetModelScale( Vector( 1, 1, self.Scale ) )

        end
        
    end
    usermessage.Hook( "BoxCrush", function( um )

        local ent = um:ReadEntity()
        if !IsValid( ent ) then return end

        ent.Scale = 1

    end    )
    usermessage.Hook( "MetalMarioMusic", function( um )

        local bool = um:ReadBool()
        
        if LocalPlayer().MetalMusic then
            LocalPlayer().MetalMusic:Stop()
        end

        if bool then
            LocalPlayer().MetalMusic = CreateSound( LocalPlayer(), "nostalgia/mario/metalmario.mp3" )
            LocalPlayer().MetalMusic:PlayEx( 100, 100 )
        end

    end    )


    local EFFECT = {}
    function EFFECT:Init( data )

        local vOffset = data:GetOrigin()
        local NumParticles = 32
    
        local emitter = ParticleEmitter( vOffset )
        for i=0, NumParticles do
            local particle = emitter:Add( "sprites/star", vOffset )
            if particle then
                particle:SetVelocity( VectorRand() * 250 )
                particle:SetLifeTime( 0 )
                particle:SetDieTime( 3 )
                particle:SetStartAlpha( 255 )
                particle:SetEndAlpha( 150 )
                particle:SetStartSize( 8 )
                particle:SetEndSize( 2 )

                local col = Color( 0, 0, 255 )
                if i > 16 then
                    col = Color( 0, 50, 255 )
                    col.g = col.g - math.random( 0, 50 )
                end
                particle:SetColor( col.r, col.g, math.Rand( 0, 50 ) )
                particle:SetRoll( math.Rand( 0, 360 ) )
                particle:SetRollDelta( math.Rand( -2, 2 ) )
                particle:SetAirResistance( 100 )
            end
        end
        emitter:Finish()
    end

    function EFFECT:Think() return false end
    function EFFECT:Render() end

    effects.Register( EFFECT, "metalbox_stars" )

end
 
 