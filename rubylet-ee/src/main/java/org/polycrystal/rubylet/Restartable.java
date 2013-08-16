package org.polycrystal.rubylet;

import javax.servlet.ServletException;

public interface Restartable {

    public void restart() throws ServletException;

}
