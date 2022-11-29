abstract type Constraint end

mutable struct ConstraintDetails
    name::String
    key::String
    reason::String
end

function get_key(cons::Constraint)
    return cons.attribute.key
end

struct OpConstraint <: Constraint
    attribute::ConstraintDetails
    OpConstraint(key) = new(ConstraintDetails("工序限制",key, ""))
end

struct OrderStartConstraint <: Constraint
    attribute::ConstraintDetails
    OrderStartConstraint(key) = new(ConstraintDetails("工單可開始時間限制",key, ""))
end

struct MaterialConstraint <: Constraint
    attribute::ConstraintDetails
    MaterialConstraint(key) = new(ConstraintDetails("物料限制",key, ""))
end

struct StencilConstraint <: Constraint
    attribute::ConstraintDetails
    StencilConstraint(key) = new(ConstraintDetails("鋼板限制", key, ""))
end

struct NextOpConstraint <: Constraint
    attribute::ConstraintDetails
    NextOpConstraint(key) = new(ConstraintDetails("拉式限制", key, ""))
end

struct FixtureConstraint <: Constraint
    attribute::ConstraintDetails
    FixtureConstraint(key) = new(ConstraintDetails("治具限制", key, ""))
end

function get_name(cons::Constraint) 
    return cons.attribute.name
end

function get_ES(sup_data, op, cons::OpConstraint, rs_id)
    key = get_key(cons)
    ES = sup_data["order_ES_dict"][key]
    # sup_data[""]
    return (key, ES)
end
function get_ES(sup_data, op, cons::OrderStartConstraint, rs_id)
    key = get_key(cons)
    ES = 10*3600
    return (key, ES)
end
function get_ES(sup_data, op, cons::NextOpConstraint, rs_id)
    key = get_key(cons)

    ES = op.info["next_op_constraint_ES"]
    # sup_data[""]
    return (key, ES)
end
function get_ES(sup_data, op, cons::StencilConstraint, rs_id)
    key = get_key(cons)
    stencil_group = get_constraint_resource(sup_data, cons::StencilConstraint)
    stencil = nothing
    if haskey(sup_data["subresources_assigned"], op.info["order_id"]*"-"*op.id)
        for subresource in stencil_group.attributes.subresources
            if subresource.attributes.id == sup_data["subresources_assigned"][op.info["order_id"]*"-"*op.id]
                stencil = subresource
            end
        end
    else
        stencil = get_best_object(sup_data["current_stencil_dict"], stencil_group, rs_id)
        sup_data["subresources_assigned"][op.info["order_id"]*"-"*op.id] = stencil.attributes.id#紀錄工單挑選的鋼板。
    end
    ES = get_ER(stencil)
    user = get!(stencil.info, "user", "") #回傳上一個使用該資源的對象
    
    return ([stencil.info["user"], stencil.attributes.id], ES)
end
function get_ES(sup_data, op, cons::MaterialConstraint, rs_id)
    key = get_key(cons)
    main_ES = sup_data["material_info"][key][end][2]
    main_material = sup_data["material_info"][key][end][1]

    material_ES_set = sup_data["material_info"][key]

    material = sup_data["WO"][key].info["pd_id"]
    return (string(material_ES_set), main_ES)
end
function get_constraint_resource(sup_data, cons::StencilConstraint)
    key = get_key(cons)
    stencil_group = sup_data["stencil_group_dict"][key]
    return stencil_group
end
function get_ES(sup_data, op, cons::FixtureConstraint, rs_id)
    key = get_key(cons)
    ES = 0
    return ES
end
function update!(sup_data, cons::MaterialConstraint, update_data)
    #不需要做任何事情
end
function update!(sup_data, cons::NextOpConstraint, update_data)
    #不需要做任何事情
end
function update!(sup_data, cons::OpConstraint, update_data)
    key = get_key(cons)
    
    sup_data["order_ES_dict"][key] = update_data["finish_time"]
end

function update!(sup_data, cons::OrderStartConstraint, update_data)
 #不需要做任何事情
end
function update!(sup_data, cons::StencilConstraint, update_data)
    finish_time = update_data["finish_time"]
    data_key = update_data["data_key"]
    rs_id = update_data["rs_id"]

    key = get_key(cons)
    stencil_group = sup_data["stencil_group_dict"][key]
    stencil_id = update_data["鋼板限制"][2] #1=user, 2= stencil key

    stencil = nothing
    for subresource in stencil_group.attributes.subresources
        if subresource.attributes.id == stencil_id
            stencil = subresource
        end
    end
    # stencil = SubResourceModule.get_best_object(sup_data["current_stencil_dict"], stencil_group, rs_id)#TODO: 如果要改成最近可以使用的鋼板 要替換成List or..
    sup_data["current_stencil_dict"][rs_id] = stencil.attributes.id
    stencil.attributes.ER = finish_time

    stencil.info["user"] = data_key
end