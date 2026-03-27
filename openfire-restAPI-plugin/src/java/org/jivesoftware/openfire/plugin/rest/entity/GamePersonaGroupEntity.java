package org.jivesoftware.openfire.plugin.rest.entity;

import com.fasterxml.jackson.annotation.JsonProperty;

import javax.xml.bind.annotation.XmlElement;
import javax.xml.bind.annotation.XmlRootElement;
import java.util.List;

@XmlRootElement(name = "gamePersonaGroup")
public class GamePersonaGroupEntity {

    List<Long> members;

    public GamePersonaGroupEntity() {
    }

    public GamePersonaGroupEntity(List<Long> members) {
        this.members = members;
    }

    @XmlElement(name = "member")
    @JsonProperty(value = "members")
    public List<Long> getMembers() {
        return members;
    }

    public void setMembers(List<Long> members) {
        this.members = members;
    }
}
